//
//  JDJsonDecoder.h
//  JDJsonDecoder
//
//  Created by Eungkyu Song on 12. 12. 4..
//  Copyright (c) 2012년 Ticketmonster, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define JDJsonDecoderErrorDomain @"JDJsonDecoderError"

typedef NS_ENUM(int, JDJsonDecoderError) {
    JDJsonDecoderErrorNotDictionary
};

@protocol JDJsonDecoding <NSObject>

- (id)objectWithValue:(id)value;

@end

@interface JDJsonDecoder : NSObject

+ (id)objectForClass:(Class)cls withData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error;
+ (id)objectForClass:(Class)cls withStream:(NSInputStream *)stream options:(NSJSONReadingOptions)opt error:(NSError **)error;
+ (id)objectForClass:(Class)cls withJSONObject:(id)jsonObject error:(NSError **)error;

@end
