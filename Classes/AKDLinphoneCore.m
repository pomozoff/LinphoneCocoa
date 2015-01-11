//
//  AKDLinphoneCore.m
//  LinphoneCocoa
//
//  Created by Антон on 10.01.15.
//  Copyright (c) 2015 Akademon Ltd. All rights reserved.
//

#import "AKDLinphoneCore.h"
#import "linphonecore.h"

#pragma mark - constants

static const NSTimeInterval linphoneCoreIterateInterval = 0.02f;
static NSString *mainThreadAssertMessage = @"This should be called from the main thread";
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
    LinphoneCore *_lc;
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

- (void)startWithIdentity:(NSString *)identity andPassword:(NSString *)password {
#if DEBUG
    [self startLoggingToFile:NULL withLevel:LCLogLevelDebug]; // Debug logs to stdout
#endif
    
    dispatch_async(_serilaLinphoneQueue, ^(void) {
        if (_lc) {
            [AKDLinphoneLogger log:LCLogLevelError formatString:@"Linphone core already running, exiting"];
            return;
        }
        
        [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Clearing blocks queues"];
        [self.registrationClearedBlocksQueue removeAllObjects];
        
        self.identity = identity;
        self.password = password;
        
        LinphoneCoreVTable vtable = {0};
        vtable.registration_state_changed = registration_state_changed;
        
        LinphoneProxyConfig *proxy_cfg;
        LinphoneAddress *from;
        LinphoneAuthInfo *info;
        
        [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Call iterate once immediately in order to initiate background connections with sip server or remote provisioning grab, if any"];
        linphone_core_iterate(_lc);
        
        [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Starting core iterate timer"];
        [self startTimer];
    });
}
- (void)stop {
    dispatch_async(_serilaLinphoneQueue, ^(void) {
        if (!_lc) {
            [AKDLinphoneLogger log:LCLogLevelError formatString:@"Linphone core is absent, exiting"];
            return;
        }
        
        [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Disabling registration on proxy"];
        LinphoneProxyConfig *proxy_cfg;
        
        linphone_core_get_default_proxy(_lc, &proxy_cfg);        // get default proxy config
        linphone_proxy_config_edit(proxy_cfg);                   // start editing proxy configuration
        linphone_proxy_config_enable_register(proxy_cfg, FALSE); // de-activate registration for this proxy config
        linphone_proxy_config_done(proxy_cfg);                   // initiate REGISTER with expire = 0
        
        [self.registrationClearedBlocksQueue addObject:[NSBlockOperation blockOperationWithBlock:^(void) {
            [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Stopping timer"];
            [self stopTimer];

            [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Destroying linphone core"];
            linphone_core_destroy(_lc);
            _lc = NULL;
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
            operationsQueueArray = [[AKDLinphoneCore sharedInstance] registrationClearedBlocksQueue];
            break;
        case LinphoneRegistrationFailed:
            [AKDLinphoneLogger log:LCLogLevelMessage formatString:@"Registration failed"];
            break;
        default:
            [AKDLinphoneLogger log:LCLogLevelError formatString:@"Unknown registration state received"];
            break;
    }
    
    for (NSOperation *operation in operationsQueueArray) {
        [operation start];
    }
    
    [operationsQueueArray removeAllObjects];
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
    if (!_iterateTimer) {
        _iterateTimer = [self timerWithInterval:linphoneCoreIterateInterval inQueue:_serilaLinphoneQueue executesBlock:^(void) {
            linphone_core_iterate(_lc);
        }];
    }
}
- (void)stopTimer {
    if (_iterateTimer) {
        dispatch_source_cancel(_iterateTimer);
        _iterateTimer = nil;
    }
}

@end
