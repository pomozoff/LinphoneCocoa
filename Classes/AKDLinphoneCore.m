//
//  AKDLinphoneCore.m
//  LinphoneCocoa
//
//  Created by Антон on 10.01.15.
//  Copyright (c) 2015 Akademon Ltd. All rights reserved.
//

#import "AKDLinphoneCore.h"

#import "linphone/linphonecore.h"

#define ASSERT_CORRECT_THREAD NSAssert(strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), timerSerialQueueName) == 0, @"Should be run in serial queue named %s", timerSerialQueueName)

#pragma mark - constants

static const NSTimeInterval linphoneCoreIterateInterval = 0.02f;
static NSString *mainThreadAssertMessage = @"This should be called from the main thread";
static NSString *linphoneCoreErrorDomain = @"ru.akademon.linphonecocoa";
static const char *timerSerialQueueName = "ru.akademon.linphonecocoa.iterateSerialQueue";

#pragma mark - category

@interface AKDLinphoneCore ()

@property (nonatomic, copy, readwrite) NSString *identity;
@property (nonatomic, copy, readwrite) NSString *password;

@property (nonatomic, copy, readwrite) NSString *logFile;
@property (nonatomic, assign, readwrite) LCLogLevel logLevel;

@property (nonatomic, strong) NSMutableArray *registrationClearedBlocksQueue;

@end

@implementation AKDLinphoneCore {
    dispatch_source_t _iterateTimer;
    dispatch_queue_t _serilaLinphoneQueue;
    LinphoneCore *_linphoneCore;
    FILE *_lcLogFile;
}

#pragma mark - initialize

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}
- (instancetype)init {
    if (self = [super init]) {
        _logFile = nil;
        _logLevel = LCLogLevelNone;
        _iterateTimer = nil;
        _serilaLinphoneQueue = dispatch_queue_create(timerSerialQueueName, DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - public

- (void)startWithIdentity:(NSString *)identity andPassword:(NSString *)password completion:(void (^)(NSError *))completion {
#if DEBUG
    [self startLoggingToFile:NULL withLevel:LCLogLevelDebug | LCLogLevelError | LCLogLevelFatal | LCLogLevelMessage | LCLogLevelTrace | LCLogLevelWarning]; // Log everything to stdout
#endif
    
    dispatch_async(_serilaLinphoneQueue, ^(void) {
        if (_linphoneCore) {
            NSString *errorString = @"Can't start linphone core";
            NSString *reasonString = @"Looks like another linphone core is already running";
            NSString *suggestionString = @"Do not try start core more times than once, use existing one";

            [AKDLinphoneLogger log:LCLogLevelError formatString:errorString];
            completion([NSError errorWithDomain:linphoneCoreErrorDomain
                                           code:LCErrorCodeLinphoneCoreAlreadyStarted
                                       userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(errorString, nil),
                                                  NSLocalizedFailureReasonErrorKey: NSLocalizedString(reasonString, nil),
                                                  NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(suggestionString, nil)
                                                  }]);
            return;
        }
        
        LinphoneCoreVTable vtable = {
            .registration_state_changed = registration_state_changed
        };

        [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Create linphone core"];
        _linphoneCore = linphone_core_new(&vtable, NULL, NULL, NULL);
        
        [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Create proxy config"];
        LinphoneProxyConfig *proxy_cfg = linphone_proxy_config_new();
        
        const char *cIdentity = [identity cStringUsingEncoding:NSUTF8StringEncoding];
        LinphoneAddress *from = linphone_address_new(cIdentity);
        if (!from) {
            linphone_core_destroy(_linphoneCore);
            _linphoneCore = NULL;
            
            NSString *errorString = [NSString stringWithFormat:@"Can't parse identity %@", identity];
            NSString *reasonString = [NSString stringWithFormat:@"%@ is not a valid sip uri", identity];
            NSString *suggestionString = @"Identity must be like sip:toto@sip.linphone.org";
            
            [AKDLinphoneLogger log:LCLogLevelError formatString:errorString];
            completion([NSError errorWithDomain:linphoneCoreErrorDomain
                                           code:LCErrorCodeInvalidIdentity
                                       userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(errorString, nil),
                                                  NSLocalizedFailureReasonErrorKey: NSLocalizedString(reasonString, nil),
                                                  NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(suggestionString, nil)
                                                  }]);
            return;
        }
        if (password) {
            // create authentication structure from identity
            const char *cPassword = [identity cStringUsingEncoding:NSUTF8StringEncoding];
            LinphoneAuthInfo *info = linphone_auth_info_new(linphone_address_get_username(from), NULL, cPassword, NULL, NULL, NULL);
            linphone_core_add_auth_info(_linphoneCore, info); // add authentication info to LinphoneCore
        }
        
        self.identity = identity;
        self.password = password;
        
        const char *server_addr = linphone_address_get_domain(from);   // extract domain address from identity

        // configure proxy entries
        linphone_proxy_config_set_identity(proxy_cfg, cIdentity);      // set identity with user name and domain
        linphone_proxy_config_set_server_addr(proxy_cfg, server_addr); // we assume domain = proxy server address
        linphone_proxy_config_enable_register(proxy_cfg, TRUE);        // activate registration for this proxy config
        linphone_address_destroy(from);                                // release resource
        
        linphone_core_add_proxy_config(_linphoneCore, proxy_cfg);      // add proxy config to linphone core
        linphone_core_set_default_proxy(_linphoneCore, proxy_cfg);     // set to default proxy
        
        [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Clearing blocks queues"];
        [self.registrationClearedBlocksQueue removeAllObjects];

        [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Call iterate once immediately in order to initiate background connections with sip server or remote provisioning grab, if any"];
        linphone_core_iterate(_linphoneCore);
        
        [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Starting core iterate timer"];
        [self startTimer];
    });
}
- (void)stop {
    dispatch_async(_serilaLinphoneQueue, ^(void) {
        if (!_linphoneCore) {
            [AKDLinphoneLogger log:LCLogLevelError formatString:@"Linphone core is absent, exiting"];
            return;
        }
        
        [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Disabling registration on proxy"];
        LinphoneProxyConfig *proxy_cfg;
        
        linphone_core_get_default_proxy(_linphoneCore, &proxy_cfg);        // get default proxy config
        linphone_proxy_config_edit(proxy_cfg);                   // start editing proxy configuration
        linphone_proxy_config_enable_register(proxy_cfg, FALSE); // de-activate registration for this proxy config
        linphone_proxy_config_done(proxy_cfg);                   // initiate REGISTER with expire = 0
        
        [self.registrationClearedBlocksQueue addObject:[NSBlockOperation blockOperationWithBlock:^(void) {
            [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Stopping timer"];
            [self stopTimer];

            [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Destroying linphone core"];
            linphone_core_destroy(_linphoneCore);
            _linphoneCore = NULL;
            
            [self stopLogging];
        }]];
    });
}

- (void)startLoggingToFile:(NSString *)logFile withLevel:(LCLogLevel)logLevel {
    dispatch_async(_serilaLinphoneQueue, ^(void) {
        self.logLevel = logLevel;
        
        if (logFile) {
            _lcLogFile = fopen([self.logFile cStringUsingEncoding:NSUTF8StringEncoding], "w+");
        }
        
        if (_lcLogFile) {
            self.logFile = logFile;
        } else {
            self.logFile = nil;
        }
        
        linphone_core_set_log_file(_lcLogFile);
        linphone_core_set_log_level((OrtpLogLevel)logLevel);
        
        if (logFile && (!_lcLogFile) && (logLevel != LCLogLevelNone)) {
            [AKDLinphoneLogger log:LCLogLevelError formatString:@"Opening file error: %@, logging to stdout", logFile];
        }
    });
}
- (void)stopLogging {
    dispatch_async(_serilaLinphoneQueue, ^(void) {
        linphone_core_set_log_level((OrtpLogLevel)LCLogLevelNone);
        if (_lcLogFile) {
            fclose(_lcLogFile);
            _lcLogFile = NULL;
        }
    });
}

#pragma mark - callbacks

static void registration_state_changed(struct _LinphoneCore *lc, LinphoneProxyConfig *cfg, LinphoneRegistrationState cstate, const char *message) {
    [[AKDLinphoneCore sharedInstance] registrationStateChanged:cstate forLinphoneCore:lc proxyConfig:cfg message:message];
}

#pragma mark - private properites

#pragma mark - private methods

- (dispatch_source_t)timerWithInterval:(double)interval inQueue:(dispatch_queue_t)queue executesBlock:(dispatch_block_t)block {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (timer) {
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, interval * NSEC_PER_SEC), interval * NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }
    return timer;
}

- (void)startTimer {
    ASSERT_CORRECT_THREAD;

    if (!_iterateTimer) {
        _iterateTimer = [self timerWithInterval:linphoneCoreIterateInterval inQueue:_serilaLinphoneQueue executesBlock:^(void) {
            ASSERT_CORRECT_THREAD;
            linphone_core_iterate(_linphoneCore);
        }];
    }
}
- (void)stopTimer {
    ASSERT_CORRECT_THREAD;

    if (_iterateTimer) {
        dispatch_source_cancel(_iterateTimer);
        _iterateTimer = nil;
    }
}

- (void)registrationStateChanged:(LinphoneRegistrationState)cstate forLinphoneCore:(struct _LinphoneCore *)linphoneCore proxyConfig:(LinphoneProxyConfig *)proxy_cfg message:(const char *)message {
    ASSERT_CORRECT_THREAD;

    NSMutableArray *operationsQueueArray = nil;
    
    switch (cstate) {
        case LinphoneRegistrationNone:
            [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Initial state for registrations"];
            break;
        case LinphoneRegistrationProgress:
            [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Registration is in progress"];
            break;
        case LinphoneRegistrationOk:
            [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Registration is successful"];
            break;
        case LinphoneRegistrationCleared:
            [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Unregistration succeeded"];
            operationsQueueArray = self.registrationClearedBlocksQueue;
            break;
        case LinphoneRegistrationFailed:
            [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Registration failed"];
            break;
        default:
            [AKDLinphoneLogger log:LCLogLevelError formatString:@"Unknown registration state received"];
            break;
    }
    
    [[AKDLinphoneCore sharedInstance] performDelayedOperationsForQueue:operationsQueueArray];
    [operationsQueueArray removeAllObjects];
}

- (void)performDelayedOperationsForQueue:(NSArray *)operationsQueueArray {
    for (NSOperation *operation in operationsQueueArray) {
        [operation start];
    }
}

@end
