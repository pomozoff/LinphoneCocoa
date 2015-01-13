//
//  AKDLinphoneCoreTests.m
//  LinphoneCocoa
//
//  Created by Антон on 11.01.15.
//  Copyright (c) 2015 Akademon Ltd. All rights reserved.
//

@import XCTest;

#import "LinphoneCocoa.h"

@interface AKDLinphoneCoreTests : XCTestCase

@end

@implementation AKDLinphoneCoreTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testLinphoneCoreStartWithEmptyIdentity {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Server registration"];

    [[AKDLinphoneCore sharedInstance] startWithIdentity:nil andPassword:nil completion:^(NSError *error) {
        XCTAssert(error != nil, @"Should be error on start linphone server with empty identity");
        if (error) {
            [expectation fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

/*
 [self waitForExpectationsWithTimeout:1
 handler:^(NSError *error) {
 // handler is called on _either_ success or failure
 if (error != nil) {
 XCTFail(@"timeout error: %@", error);
 }
 }];
 
- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}
*/

@end
