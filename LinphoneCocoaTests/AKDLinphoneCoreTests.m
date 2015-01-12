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

@property (nonatomic, copy) NSString *identity;
@property (nonatomic, copy) NSString *password;

@end

@implementation AKDLinphoneCoreTests

- (void)setUp {
    [super setUp];
    
    self.identity = nil;
    self.password = nil;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testLinphoneCoreStart {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Server registration"];

    [[AKDLinphoneCore sharedInstance] startWithIdentity:nil andPassword:nil completion:^(NSError *error) {
        XCTAssert(error == nil, @"No errors at start");
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5
                                 handler:^(NSError *error) {
                                     // handler is called on _either_ success or failure
                                     if (error != nil) {
                                         XCTFail(@"timeout error: %@", error);
                                     }
                                 }];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
