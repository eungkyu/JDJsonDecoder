//
//  JDJsonDecoder.h
//  JDJsonDecoder
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

#import <Foundation/Foundation.h>

#define JDJsonDecoderErrorDomain @"JDJsonDecoderError"

typedef NS_ENUM(NSUInteger, JDJsonDecoderError) {
    JDJsonDecoderErrorNoClass
};

typedef NS_OPTIONS(NSUInteger, JDJsonDecoderOption) {
    JDJsonDecoderOptionNone = 0,
    JDJsonDecoderOptionPreventNil = 1 << 0
};

@protocol JDJsonDecoding <NSObject>

- (id)objectForClass:(Class)cls withValue:(id)value;

@end

@interface JDJsonDecoder : NSObject

+ (id)objectForClass:(Class)cls withData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error;
+ (id)objectForClass:(Class)cls withStream:(NSInputStream *)stream options:(NSJSONReadingOptions)opt error:(NSError **)error;
+ (id)objectForClass:(Class)cls withJSONObject:(id)jsonObject option:(JDJsonDecoderOption)option error:(NSError **)error;
+ (void)registerGlobalHandlerClass:(Class)handlerCls forClass:(Class)cls;

- (id)init;
- (id)initWithOption:(JDJsonDecoderOption)option;
- (id)parseForClass:(Class)cls withJSONObject:(id)jsonObject error:(NSError **)error;
- (void)registerHandler:(id<JDJsonDecoding>)handler forClass:(Class)cls;

@end
