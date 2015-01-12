//
//  AKDLinphoneLogger.m
//  LinphoneCocoa
//
//  Created by Антон on 11.01.15.
//  Copyright (c) 2015 Akademon Ltd. All rights reserved.
//

#import "AKDLinphoneLogger.h"

#import "linphone/linphonecore.h"

@implementation AKDLinphoneLogger

+ (void)logv:(LCLogLevel)level formatString:(NSString *)formatString args:(va_list)args {
    NSString *str = [[NSString alloc] initWithFormat:formatString arguments:args];
    if(level <= LCLogLevelDebug) {
        ms_debug("%s", [str UTF8String]);
    } else if(level <= LCLogLevelMessage) {
        ms_message("%s", [str UTF8String]);
    } else if(level <= LCLogLevelWarning) {
        ms_warning("%s", [str UTF8String]);
    } else if(level <= LCLogLevelError) {
        ms_error("%s", [str UTF8String]);
    } else if(level <= LCLogLevelFatal) {
        ms_fatal("%s", [str UTF8String]);
    }
}
+ (void)log:(LCLogLevel)level formatString:(NSString *)formatString, ... {
    va_list args;
    va_start(args, formatString);
    [self logv:level formatString:formatString args:args];
    va_end(args);
}
+ (void)log:(LCLogLevel)level formatCharPointer:(const char *)formatCharPointer, ... {
    va_list args;
    va_start(args, formatCharPointer);
    if(level <= LCLogLevelDebug) {
        ortp_logv(ORTP_DEBUG, formatCharPointer, args);
    } else if(level <= LCLogLevelMessage) {
        ortp_logv(ORTP_MESSAGE, formatCharPointer, args);
    } else if(level <= LCLogLevelWarning) {
        ortp_logv(ORTP_WARNING, formatCharPointer, args);
    } else if(level <= LCLogLevelError) {
        ortp_logv(ORTP_ERROR, formatCharPointer, args);
    } else if(level <= LCLogLevelFatal) {
        ortp_logv(ORTP_FATAL, formatCharPointer, args);
    }
    va_end(args);
}

@end
