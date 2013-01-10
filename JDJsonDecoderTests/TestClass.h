//
//  TestClass.h
//  JDJsonDecoder
//
//  Created by Eungkyu Song on 13. 1. 10..
//  Copyright (c) 2013년 Ticketmonster, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TestInnerClass;

@interface TestClass : NSObject

@property (strong, nonatomic) NSArray *array;
@property (strong, nonatomic) NSDictionary *array__member;
@property (strong, nonatomic) TestInnerClass *array__member__member;
@property (assign, nonatomic) int i;
@property (strong, nonatomic) NSNumber *n;
@property (strong, nonatomic) NSURL *url;
@property (assign, nonatomic) BOOL b;
@property (assign, nonatomic) double lat;
@property (strong, nonatomic) NSString *str;

@end
