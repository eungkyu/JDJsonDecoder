//
//  JDJsonDecoder.m
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

#import "JDJsonDecoder.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#ifdef DEBUG
#define JDJSON_DEBUG
#endif

//#define JDJSON_PROFILE

#ifdef JDJSON_PROFILE
#undef JDJSON_DEBUG
#endif

#ifdef JDJSON_DEBUG
#define JDJsonDecoderWarning(format, ...) \
    NSLog(@"%@: " format, [self->_keyPath componentsJoinedByString:@"."], ##__VA_ARGS__)
#else
#define JDJsonDecoderWarning(format, ...) \
    NSLog(format, ##__VA_ARGS__)
#endif

@interface JDJsonDecoder () {
#ifdef JDJSON_DEBUG
    NSMutableArray *_keyPath;
#endif
#ifdef JDJSON_PROFILE
    NSTimeInterval _propertyTime;
    NSTimeInterval _memberClassListTime;
    NSTimeInterval _totalTime;
#endif
    NSMutableDictionary *_memberClassListMap;
}

@property (assign, nonatomic) JDJsonDecoderOption option;
@property (strong, nonatomic) NSMutableDictionary *classHandlerMap;

@end

@implementation JDJsonDecoder

+ (id)objectForClass:(Class)cls withData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error
{
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:opt error:error];
    if (jsonObject == nil)
        return nil;
    
    return [self objectForClass:cls withJSONObject:jsonObject option:JDJsonDecoderOptionNone error:error];
}

+ (id)objectForClass:(Class)cls withStream:(NSInputStream *)stream options:(NSJSONReadingOptions)opt error:(NSError **)error
{
    id jsonObject = [NSJSONSerialization JSONObjectWithStream:stream options:opt error:error];
    if (jsonObject == nil)
        return nil;
    
    return [self objectForClass:cls withJSONObject:jsonObject option:JDJsonDecoderOptionNone error:error];
}

+ (id)objectForClass:(Class)cls withJSONObject:(id)jsonObject option:(JDJsonDecoderOption)option error:(NSError **)error
{
    JDJsonDecoder *decoder = [[self alloc] initWithOption:option];
    return [decoder parseForClass:cls withJSONObject:jsonObject error:error];
}

static NSMutableDictionary *globalHandlerClsMap;

+ (void)registerGlobalHandlerClass:(Class)handlerCls forClass:(Class)cls
{
    if (![handlerCls conformsToProtocol:@protocol(JDJsonDecoding)])
        [NSException raise:NSInternalInconsistencyException format:@"%@ does not confirm %@ protocol", NSStringFromClass(handlerCls), NSStringFromProtocol(@protocol(JDJsonDecoding))];
    
    if (globalHandlerClsMap == nil)
        globalHandlerClsMap = [NSMutableDictionary dictionaryWithCapacity:1];
    
    [globalHandlerClsMap setObject:handlerCls forKey:[NSValue valueWithNonretainedObject:cls]];
}

- (id)init
{
    return [self initWithOption:JDJsonDecoderOptionNone];
}

- (id)initWithOption:(JDJsonDecoderOption)option
{
    self = [super init];
    if (self) {
#ifdef JDJSON_DEBUG
        _keyPath = [[NSMutableArray alloc] init];
#endif
        
        self.option = option;
        for (NSValue *key in globalHandlerClsMap) {
            Class handlerCls = globalHandlerClsMap[key];
            [self registerHandler:[[handlerCls alloc] init] forClass:[key nonretainedObjectValue]];
        }
    }
    
    return self;
}

- (void)registerHandler:(id<JDJsonDecoding>)handler forClass:(Class)cls
{
    if (self.classHandlerMap == nil)
        self.classHandlerMap = [[NSMutableDictionary alloc] initWithCapacity:1];
    
    [self.classHandlerMap setObject:handler forKey:[NSValue valueWithNonretainedObject:cls]];
}

- (id)parseForClass:(Class)cls withJSONObject:(id)jsonObject error:(NSError **)error
{
    if (cls == nil || cls == [NSNull class]) {
        if (error)
            *error = [NSError errorWithDomain:JDJsonDecoderErrorDomain code:JDJsonDecoderErrorNoClass userInfo:@{NSLocalizedDescriptionKey : @"cls is nil or [NSNull class]"}];
        return nil;
    }
    
    return getObjectForClass(self, cls, nil, 0, jsonObject);
}

static id getObjectForClass(JDJsonDecoder *self, Class cls, NSArray *memberClassList, NSUInteger index, id value)
{
    if (!cls) {
        if (value == [NSNull null])
            return @0;
        
        return getNumberForPrimitiveType(self, value);
    }

    if (value == [NSNull null]) {
        if (self.option & JDJsonDecoderOptionPreventNil)
            return [[cls alloc] init];
        else
            return nil;
    }
    
    if ([cls isSubclassOfClass:[NSArray class]])
        return getArrayForClass(self, cls, memberClassList, index, value);
    
    if ([cls isSubclassOfClass:[NSDictionary class]])
        return getDictionaryForClass(self, cls, memberClassList, index, value);
    
    if (self.classHandlerMap != nil) {
        id<JDJsonDecoding> handler = self.classHandlerMap[[NSValue valueWithNonretainedObject:cls]];
        if (handler)
            return [handler objectForClass:cls withValue:value];
    }
    
    if ([cls isSubclassOfClass:[NSString class]])
        return getStringForClass(self, cls, value);
    
    if ([cls isSubclassOfClass:[NSNumber class]])
        return getNumberForClass(self, cls, value);

    return getNativeObjectForClass(self, cls, value);
}

static NSNumber *getNumberForPrimitiveType(JDJsonDecoder *self, id value)
{
    if (![[value class] isSubclassOfClass:[NSNumber class]]) {
        JDJsonDecoderWarning(@"expect NSNumber subclass but %@, use @0", NSStringFromClass([value class]));
        return @0;
    }
    
    return value;
}

static NSArray *getArrayForClass(JDJsonDecoder *self, Class cls, NSArray *memberClassList, NSUInteger index, id value)
{
    if (![[value class] isSubclassOfClass:[NSArray class]]) {
        JDJsonDecoderWarning(@"expect NSArray subclass but %@, use empty one", NSStringFromClass([value class]));
        return [[cls alloc] init];
    }
    
    if (memberClassList.count <= index) {
        JDJsonDecoderWarning(@"member type of an array not specified, use empty one");
        return [[cls alloc] init];
    }
    
    Class memberCls = [memberClassList[index] nonretainedObjectValue];
    
    NSArray *array = value;
    NSMutableArray *object = [[NSMutableArray alloc] initWithCapacity:array.count];
    for (id val in array) {
        id member = getObjectForClass(self, memberCls, memberClassList, index + 1, val);
        if (member == nil)
            member = [NSNull null];
        
        [object addObject:member];
    }

    if (cls == [NSArray class] || cls == [NSMutableArray class])
        return object;

    return [[cls alloc] initWithArray:object copyItems:NO];
}

static NSDictionary *getDictionaryForClass(JDJsonDecoder *self, Class cls, NSArray *memberClassList, NSUInteger index, id value)
{
    if (![[value class] isSubclassOfClass:[NSDictionary class]]) {
        JDJsonDecoderWarning(@"expect NSDictionary subclass but %@, use empty one", NSStringFromClass([value class]));
        return [[cls alloc] init];
    }
    
    if (memberClassList.count <= index) {
        JDJsonDecoderWarning(@"member type of a dictionary not specified, use empty one");
        return [[cls alloc] init];
    }
    
    Class memberCls = [memberClassList[index] nonretainedObjectValue];
    
    NSDictionary *dictionary = value;
    NSMutableDictionary *object = [[NSMutableDictionary alloc] initWithCapacity:dictionary.count];
    for (NSString *key in dictionary) {
#ifdef JDJSON_DEBUG
        [self->_keyPath addObject:key];
#endif
        id val = dictionary[key];
        id member = getObjectForClass(self, memberCls, memberClassList, index + 1, val);
        if (member == nil)
            member = [NSNull null];
        
        [object setObject:member forKey:key];
#ifdef JDJSON_DEBUG
        [self->_keyPath removeLastObject];
#endif
    }

    if (cls == [NSDictionary class] || cls == [NSMutableDictionary class])
        return object;

    return [[cls alloc] initWithDictionary:object copyItems:NO];
}

static NSString *getStringForClass(JDJsonDecoder *self, Class cls, id value)
{
    if (![[value class] isSubclassOfClass:[NSString class]]) {
        JDJsonDecoderWarning(@"expect NSString subclass but %@, use empty one", NSStringFromClass([value class]));
        return [[cls alloc] init];
    }

    if (cls == [NSString class])
        return value;

    return [[cls alloc] initWithString:value];
}

static NSNumber *getNumberForClass(JDJsonDecoder *self, Class cls, id value)
{
    if (![[value class] isSubclassOfClass:[NSNumber class]]) {
        JDJsonDecoderWarning(@"expect NSNumber subclass but %@, use @0", NSStringFromClass([value class]));
        return @0;
    }
    
    return value;
}

static id getNativeObjectForClass(JDJsonDecoder *self, Class cls, id value)
{
    if (![value isKindOfClass:[NSDictionary class]]) {
        JDJsonDecoderWarning(@"expect NSDictionary subclass but %@, use empty object", NSStringFromClass([value class]));
        return [[cls alloc] init];
    }
    
    id object = [[cls alloc] init];
    for (NSString *name in value) {
#ifdef JDJSON_DEBUG
        [self->_keyPath addObject:name];
#endif
        id memberObject = value[name];
        const char *utf8Name = [name UTF8String];
        
        objc_property_t property = class_getProperty(cls, utf8Name);
        if (property == NULL) {
            JDJsonDecoderWarning(@"no property for %@, ignoring", name);
#ifdef JDJSON_DEBUG
            [self->_keyPath removeLastObject];
#endif
            continue;
        }
        
        const char *attribute = property_getAttributes(property);
        Class propertyCls = getClassForAttribute(attribute);
        NSArray *memberClassList = getMemberClassList(self, cls, property, utf8Name);
        
        id member = getObjectForClass(self, propertyCls, memberClassList, 0, memberObject);
        
        @try {
            [object setValue:member forKey:name];
        }
        @catch (NSException *exception) {
            JDJsonDecoderWarning(@"no property setter for %@, ignoring", name);
        }
#ifdef JDJSON_DEBUG
        [self->_keyPath removeLastObject];
#endif
    }
    return object;
}

static Class getClassForAttribute(const char *attribute)
{
    char buf[32];
    if (strncmp(attribute, "T@\"", 3) != 0)
        return nil;
    
    const char *start = attribute + 3;
    size_t len = strcspn(start, "\"");
    if (len == 0)
        return nil;
    
    char *ptr = buf;
    if (len >= 32) {
        ptr = malloc(len + 1);
        if (!ptr)
            [NSException raise:NSMallocException format:@"allocing class ptr failed"];
    }
    
    strncpy(ptr, start, len);
    ptr[len] = '\0';
    
    Class cls = objc_getClass(ptr);
    
    if (len >= 32)
        free(ptr);
    
    return cls;
}

static NSArray *getMemberClassList(JDJsonDecoder *self, Class cls, objc_property_t property, const char *name)
{
    Class propertyCls = getClassForAttribute(property_getAttributes(property));
    if (propertyCls == nil)
        return nil;
    
    if (![propertyCls isSubclassOfClass:[NSArray class]] && ![propertyCls isSubclassOfClass:[NSDictionary class]])
        return nil;
    
    char *propertyName = strdup(name);
    NSMutableArray *classList = [[NSMutableArray alloc] init];
    
    while (YES) {
        char *memberName;
        if (asprintf(&memberName, "%s__member", propertyName) == -1)
            [NSException raise:NSMallocException format:@"allocing memberName failed"];
        free(propertyName);
        propertyName = memberName;
        
        objc_property_t property = class_getProperty(cls, memberName);
        if (property == NULL)
            break;
        
        const char *attribute = property_getAttributes(property);
        Class propertyCls = getClassForAttribute(attribute);
        if (propertyCls == nil)
            break;
        
        [classList addObject:[NSValue valueWithNonretainedObject:propertyCls]];
        if (![propertyCls isSubclassOfClass:[NSArray class]] && ![propertyCls isSubclassOfClass:[NSDictionary class]])
            break;
    }
    
    free(propertyName);
    return classList;
}

@end
