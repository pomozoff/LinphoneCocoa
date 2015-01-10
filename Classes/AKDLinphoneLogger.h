//
//  AKDLinphoneLogger.h
//  LinphoneCocoa
//
//  Created by Антон on 11.01.15.
//  Copyright (c) 2015 Akademon Ltd. All rights reserved.
//

@import Foundation;

typedef NS_OPTIONS(NSUInteger, LCLogLevel) {
    LCLogLevelNone    = 0,
    LCLogLevelMessage = 1 << 1,
    LCLogLevelWarning = 1 << 2,
    LCLogLevelError   = 1 << 3,
    LCLogLevelFatal   = 1 << 4,
    LCLogLevelTrace   = 1 << 5,
    LCLogLevelDebug   = 1
};

@interface AKDLinphoneLogger : NSObject

+ (void)log:(LCLogLevel)level formatString:(NSString *)formatString, ...;
+ (void)log:(LCLogLevel)level formatCharPointer:(const char *)formatCharPointer, ...;

@end
