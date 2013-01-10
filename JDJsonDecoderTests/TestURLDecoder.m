//
//  TestURLDecoder.m
//  JDJsonDecoder
//
//  Created by Eungkyu Song on 13. 1. 10..
//  Copyright (c) 2013년 Ticketmonster, Inc. All rights reserved.
//

#import "TestURLDecoder.h"

@implementation TestURLDecoder

- (id)objectForClass:(Class)cls withValue:(id)value
{
    if (![[value class] isSubclassOfClass:[NSString class]]) {
        if (value == [NSNull null])
            return nil;

        return [[cls alloc] init];
    }

    return [[cls alloc] initWithString:value];
}

@end
