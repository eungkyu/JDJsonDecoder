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
#import "TestClass.h"
#import "TestMutableClass.h"
#import "TestURLDecoder.h"

@interface JDJsonDecoderTests () {
    NSData *testJsonData;
    NSDictionary *testJsonDic;
}

@end

@implementation JDJsonDecoderTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
    NSString *jsonString = @"{ \
        \"array\" : [ \
            { \
                \"first\" : { \"name\" : \"John\", \"b\" : true }, \
                \"second\" : { \"name\" : \"Jane\", \"b\" : false } \
            }, \
            { \
                \"one\" : { \"name\" : \"Ann\", \"b\" : true }, \
                \"two\" : { \"name\" : null, \"b\" : false } \
            } \
        ], \
        \"i\" : 10, \
        \"n\" : 100, \
        \"url\" : \"http://test.com\", \
        \"b\" : 0, \
        \"lat\" : 10.0, \
        \"str\" : \"string\" \
    }";
    testJsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    
    testJsonDic = @{
        @"array" : @[
            @{
                @"first" : @{ @"name" : @"John", @"b" : @YES },
                @"second" : @{ @"name" : @"Jane", @"b" : @NO }
            },
            @{
                @"one" : @{ @"name" : @"Ann", @"b" : @YES },
                @"two" : @{ @"name" : [NSNull null], @"b" : @NO }
            }
        ],
        @"i" : @10,
        @"n" : @100,
        @"url" : @"http://test.com",
        @"b" : @0,
        @"lat" : @10.0,
        @"str" : @"string"
    };
}

- (void)tearDown
{
    // Tear-down code here.

    [super tearDown];
}

- (void)testJsonObject
{
    JDJsonDecoder *decoder = [[JDJsonDecoder alloc] init];
    TestURLDecoder *urlDecoder = [[TestURLDecoder alloc] init];
    [decoder registerHandler:urlDecoder forClass:[NSURL class]];

    TestClass *obj = [decoder parseForClass:[TestClass class] withJSONObject:testJsonDic error:nil];

    STAssertNotNil(obj, @"not nil");

    STAssertEquals([obj.array[0][@"first"] name], testJsonDic[@"array"][0][@"first"][@"name"], @"array[0] -> dic[first] -> name member");
    STAssertEquals([obj.array[0][@"first"] b], [testJsonDic[@"array"][0][@"first"][@"b"] boolValue], @"array[0] -> dic[first] -> b member");

    STAssertEquals([obj.array[0][@"second"] name], testJsonDic[@"array"][0][@"second"][@"name"], @"array[0] -> dic[second] -> name member");
    STAssertEquals([obj.array[0][@"second"] b], [testJsonDic[@"array"][0][@"second"][@"b"] boolValue], @"array[0] -> dic[second] -> b member");

    STAssertEquals([obj.array[1][@"one"] name], testJsonDic[@"array"][1][@"one"][@"name"], @"array[1] -> dic[one] -> name member");
    STAssertEquals([obj.array[1][@"one"] b], [testJsonDic[@"array"][1][@"one"][@"b"] boolValue], @"array[1] -> dic[one] -> b member");

    STAssertNil([obj.array[1][@"two"] name], @"array[1] -> dic[two] -> name member");
    STAssertEquals([obj.array[1][@"two"] b], [testJsonDic[@"array"][1][@"two"][@"b"] boolValue], @"array[1] -> dic[two] -> b member");

    STAssertEquals(obj.i, [testJsonDic[@"i"] intValue], @"int value");
    STAssertEquals(obj.n, testJsonDic[@"n"], @"NSNumber value");
    STAssertEqualObjects(obj.url, [NSURL URLWithString:testJsonDic[@"url"]], @"NSURL value");
    STAssertEquals(obj.b, [testJsonDic[@"b"] boolValue], @"bool value");
    STAssertEqualsWithAccuracy(obj.lat, [testJsonDic[@"lat"] doubleValue], 0.01, @"double value");
    STAssertEquals(obj.str, testJsonDic[@"str"], @"NSString");
}

- (void)testRealJson
{
    [JDJsonDecoder registerGlobalHandlerClass:[TestURLDecoder class] forClass:[NSURL class]];
    TestClass *obj = [JDJsonDecoder objectForClass:[TestClass class] withData:testJsonData options:0 error:nil];

    STAssertNotNil(obj, @"not nil");

    STAssertEqualObjects([obj.array[0][@"first"] name], @"John", @"array[0] -> dic[first] -> name member");
    STAssertEquals([obj.array[0][@"first"] b], YES, @"array[0] -> dic[first] -> b member");

    STAssertEqualObjects([obj.array[0][@"second"] name], @"Jane", @"array[0] -> dic[second] -> name member");
    STAssertEquals([obj.array[0][@"second"] b], NO, @"array[0] -> dic[second] -> b member");

    STAssertEqualObjects([obj.array[1][@"one"] name], @"Ann", @"array[1] -> dic[one] -> name member");
    STAssertEquals([obj.array[1][@"one"] b], YES, @"array[1] -> dic[one] -> b member");

    STAssertNil([obj.array[1][@"two"] name], @"array[1] -> dic[two] -> name member");
    STAssertEquals([obj.array[1][@"two"] b], NO, @"array[1] -> dic[two] -> b member");

    STAssertEquals(obj.i, 10, @"int value");
    STAssertEqualObjects(obj.n, @100, @"NSNumber value");
    STAssertEqualObjects(obj.url, [NSURL URLWithString:@"http://test.com"], @"NSURL value");
    STAssertEquals(obj.b, NO, @"bool value");
    STAssertEqualsWithAccuracy(obj.lat, 10.0, 0.01, @"double value");
    STAssertEqualObjects(obj.str, @"string", @"NSString");
}

- (void)testMutable
{
    [JDJsonDecoder registerGlobalHandlerClass:[TestURLDecoder class] forClass:[NSURL class]];
    TestMutableClass *obj = [JDJsonDecoder objectForClass:[TestMutableClass class] withData:testJsonData options:0 error:nil];

    STAssertNotNil(obj, @"not nil");

    STAssertEqualObjects([obj.array[0][@"first"] name], @"John", @"array[0] -> dic[first] -> name member");
    STAssertEquals([obj.array[0][@"first"] b], YES, @"array[0] -> dic[first] -> b member");

    STAssertEqualObjects([obj.array[0][@"second"] name], @"Jane", @"array[0] -> dic[second] -> name member");
    STAssertEquals([obj.array[0][@"second"] b], NO, @"array[0] -> dic[second] -> b member");

    STAssertEqualObjects([obj.array[1][@"one"] name], @"Ann", @"array[1] -> dic[one] -> name member");
    STAssertEquals([obj.array[1][@"one"] b], YES, @"array[1] -> dic[one] -> b member");

    STAssertNil([obj.array[1][@"two"] name], @"array[1] -> dic[two] -> name member");
    STAssertEquals([obj.array[1][@"two"] b], NO, @"array[1] -> dic[two] -> b member");

    STAssertEquals(obj.i, 10, @"int value");
    STAssertEqualObjects(obj.n, @100, @"NSNumber value");
    STAssertEqualObjects(obj.url, [NSURL URLWithString:@"http://test.com"], @"NSURL value");
    STAssertEquals(obj.b, NO, @"bool value");
    STAssertEqualsWithAccuracy(obj.lat, 10.0, 0.01, @"double value");
    STAssertEqualObjects(obj.str, @"string", @"NSString");

    STAssertNoThrow([obj.array addObject:@"object"], @"mutable array");
    STAssertNoThrow([obj.array[0] setObject:@"object" forKey:@"key"], @"mutable dictionary");
    STAssertNoThrow([obj.str appendString:@"string"], @"mutable string");
}

@end
