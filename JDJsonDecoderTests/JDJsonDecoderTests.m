//
//  JDJsonDecoderTests.m
//  JDJsonDecoderTests
//
//  Created by Eungkyu Song on 12. 12. 4..
//  Copyright (C) 2012 by Ticketmonster, Inc.

//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

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
