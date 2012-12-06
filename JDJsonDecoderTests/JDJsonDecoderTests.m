//
//  JDJsonDecoderTests.m
//  JDJsonDecoderTests
//
//  Created by Eungkyu Song on 12. 12. 4..
//  Copyright (c) 2012년 Ticketmonster, Inc. All rights reserved.
//

#import "JDJsonDecoderTests.h"
#import "JDJsonDecoder.h"

@interface TestArray : NSObject

@property (strong, nonatomic) NSArray *array;
@property (strong, nonatomic) NSString *array__member;
@property (assign, nonatomic) int i;
@property (assign, nonatomic) BOOL b;
@property (assign, nonatomic) double lat;

@end

@implementation TestArray

@end

@implementation JDJsonDecoderTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testExample
{
    TestArray *arr = [JDJsonDecoder objectForClass:[TestArray class] withJSONObject:@{
                      @"array" : @[@"test"],
                      @"i" : @10,
                      @"b" : @0,
                      @"lat" : @10.0,
                      } error:nil];
    STAssertNotNil(arr, @"nil");
    STAssertEquals(arr.array[0], @"test", @"array member");
    STAssertEquals(arr.i, 10, @"int value");
    STAssertEquals(arr.b, NO, @"bool value");
    STAssertEqualsWithAccuracy(arr.lat, 10.0, 0.01, @"double value");
}

@end
