//
//  AKDLinphoneCore.h
//  LinphoneCocoa
//
//  Created by Антон on 10.01.15.
//  Copyright (c) 2015 Akademon Ltd. All rights reserved.
//

@import Foundation;

#import "AKDLinphoneLogger.h"

typedef NS_ENUM(NSInteger, LCErrorCode) {
    LCErrorCodeNone = 0,
    LCErrorCodeLinphoneCoreAlreadyStarted,
    LCErrorCodeThereIsNoLinphoneCore,
    LCErrorCodeInvalidIdentity
};

@interface AKDLinphoneCore : NSObject

@property (nonatomic, copy, readonly) NSString *identity;
@property (nonatomic, copy, readonly) NSString *password;

@property (nonatomic, copy, readonly) NSString *logFile;
@property (nonatomic, assign, readonly) LCLogLevel logLevel;

+ (instancetype)sharedInstance;
- (instancetype)init __attribute__ ((unavailable("use sharedInstance")));

- (void)startLoggingToFile:(NSString *)logFile withLevel:(LCLogLevel)logLevel;
- (void)stopLogging;

- (void)startWithIdentity:(NSString *)identity andPassword:(NSString *)password;
- (void)stop;

@end
