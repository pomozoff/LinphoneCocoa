//
//  LinphoneCocoa.h
//  LinphoneCocoa
//
//  Created by Антон on 10.01.15.
//  Copyright (c) 2015 Akademon Ltd. All rights reserved.
//

#ifndef LinphoneCocoa_LinphoneCocoa_h
#define LinphoneCocoa_LinphoneCocoa_h

@protocol LinphoneCore <NSObject>

- (instancetype)linphoneCore;
- (void)start;
- (void)stop;

@end

#endif
