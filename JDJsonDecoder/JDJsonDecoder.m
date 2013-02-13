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
#define JDJsonDecoderWarning(format, ...) \
    NSLog(@"%@: " format, [self.keyPath componentsJoinedByString:@"."], ##__VA_ARGS__)
#else
#define JDJsonDecoderWarning(format, ...) \
    NSLog(format, ##__VA_ARGS__)
#endif

@interface JDJsonDecoder ()

@property (strong, nonatomic) NSMutableDictionary *classHandlerMap;
#ifdef DEBUG
@property (strong, nonatomic) NSMutableArray *keyPath;
#endif

@end

@implementation JDJsonDecoder

+ (id)objectForClass:(Class)cls withData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error
{
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:opt error:error];
    if (jsonObject == nil)
        return nil;
    
    return [self objectForClass:cls withJSONObject:jsonObject error:error];
}

+ (id)objectForClass:(Class)cls withStream:(NSInputStream *)stream options:(NSJSONReadingOptions)opt error:(NSError **)error
{
    id jsonObject = [NSJSONSerialization JSONObjectWithStream:stream options:opt error:error];
    if (jsonObject == nil)
        return nil;
    
    return [self objectForClass:cls withJSONObject:jsonObject error:error];
}

+ (id)objectForClass:(Class)cls withJSONObject:(id)jsonObject error:(NSError **)error
{
    JDJsonDecoder *decoder = [[self alloc] init];
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
    self = [super init];
    if (self) {
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
        self.classHandlerMap = [NSMutableDictionary dictionaryWithCapacity:1];
    
    [self.classHandlerMap setObject:handler forKey:[NSValue valueWithNonretainedObject:cls]];
}

- (id)parseForClass:(Class)cls withJSONObject:(id)jsonObject error:(NSError **)error
{
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        if (error)
            *error = [NSError errorWithDomain:JDJsonDecoderErrorDomain code:JDJsonDecoderErrorNotDictionary userInfo:@{NSLocalizedDescriptionKey : @"Top level of JSONObject must be a dictionary"}];
        return nil;
    }
    
    return [self objectForClass:cls withValue:jsonObject];
}

- (id)objectForClass:(Class)cls withValue:(id)value
{
    if (![value isKindOfClass:[NSDictionary class]]) {
        if (value == [NSNull null])
            return nil;
        
        JDJsonDecoderWarning(@"expect NSDictionary subclass but %@, use empty object", NSStringFromClass([value class]));
        return [[cls alloc] init];
    }
    
    id object = [[cls alloc] init];
    NSDictionary *dic = value;
    for (NSString *key in dic) {
#ifdef DEBUG
        [self.keyPath addObject:key];
#endif
        id val = dic[key];
    
        objc_property_t property = class_getProperty(cls, [key cStringUsingEncoding:NSUTF8StringEncoding]);
        if (property == NULL) {
            JDJsonDecoderWarning(@"no property for %@, ignoring", key);
#ifdef DEBUG
            [self.keyPath removeLastObject];
#endif
            continue;
        }
        const char *attribute = property_getAttributes(property);
        Class propertyCls = [self classFromPropertyAttribute:attribute];
        NSArray *memberAttributeList = nil;
        NSUInteger index = 0;
        if ([propertyCls isSubclassOfClass:[NSArray class]] || [propertyCls isSubclassOfClass:[NSDictionary class]]) {
            memberAttributeList = [self memberAttributeListIn:cls forProperty:property named:key];
        }
        
        id member = [self objectForAttribute:attribute andClass:propertyCls forMemberAttributeList:memberAttributeList andIndex:index withValue:val];
        
        @try {
            [object setValue:member forKey:key];
        }
        @catch (NSException *exception) {
            JDJsonDecoderWarning(@"no property setter for %@, ignoring", key);
        }
#ifdef DEBUG
        [self.keyPath removeLastObject];
#endif
    }
    return object;
}

- (NSMutableArray *)memberAttributeListIn:(Class)cls forProperty:(objc_property_t)property named:(NSString *)name
{
    NSMutableArray *clsList = [NSMutableArray array];
    while (YES) {
        name = [NSString stringWithFormat:@"%@__member", name];
        objc_property_t property = class_getProperty(cls, [name cStringUsingEncoding:NSUTF8StringEncoding]);
        if (property == NULL)
            break;
        
        const char *attribute = property_getAttributes(property);
        
        [clsList addObject:[NSValue valueWithPointer:attribute]];
        
        Class propertyCls = [self classFromPropertyAttribute:attribute];
        if (propertyCls == nil)
            break;
        
        if (![propertyCls isSubclassOfClass:[NSArray class]] && ![propertyCls isSubclassOfClass:[NSDictionary class]])
            break;
    }
    
    return clsList;
}

- (Class)classFromPropertyAttribute:(const char *)attribute
{
    char buf[32];
    if (strncmp(attribute, "T@\"", 3) != 0)
        return nil;
    
    const char *start = attribute + 3;
    size_t len = strcspn(start, "\"");
    if (len == 0)
        return nil;
    
    char *ptr = buf;
    if (len >= 32)
        ptr = malloc(len + 1);
    
    strncpy(ptr, start, len);
    ptr[len] = '\0';

    Class cls = objc_getClass(ptr);

    if (len >= 32)
        free(ptr);
    return cls;
}

- (id)objectForAttribute:(const char *)attribute andClass:(Class)cls forMemberAttributeList:(NSArray *)memberAttributeList andIndex:(NSUInteger)index withValue:(id)value
{
    if (!cls)
        return [self objectForPrimitiveType:attribute withValue:value];

    if ([cls isSubclassOfClass:[NSArray class]])
        return [self arrayForClass:cls ofMemberAttributeList:memberAttributeList andIndex:index withValue:value];
    
    if ([cls isSubclassOfClass:[NSDictionary class]])
        return [self dictionaryForClass:cls ofMemberAttributeList:memberAttributeList andIndex:index withValue:value];
    
    if (self.classHandlerMap != nil) {
        id<JDJsonDecoding> handler = self.classHandlerMap[[NSValue valueWithNonretainedObject:cls]];
        if (handler)
            return [handler objectForClass:cls withValue:value];
    }
    
    if ([cls isSubclassOfClass:[NSString class]])
        return [self stringForClass:cls withValue:value];
    
    if ([cls isSubclassOfClass:[NSNumber class]])
        return [self numberForClass:cls withValue:value];

    return [self objectForClass:cls withValue:value];
}

- (id)arrayForClass:(Class)cls ofMemberAttributeList:(NSArray *)memberAttributeList andIndex:(NSUInteger)index withValue:(id)value
{
    if (![[value class] isSubclassOfClass:[NSArray class]]) {
        if (value == [NSNull null])
            return nil;
        
        JDJsonDecoderWarning(@"expect NSArray subclass but %@, use empty one", NSStringFromClass([value class]));
        return [[cls alloc] init];
    }
    
    if (memberAttributeList.count <= index) {
        JDJsonDecoderWarning(@"member type of an array not specified, use empty one");
        return [[cls alloc] init];
    }
    
    const char *memberAttribute = [memberAttributeList[index] pointerValue];
    Class memberCls = [self classFromPropertyAttribute:memberAttribute];
    
    NSArray *array = value;
    NSMutableArray *object = [NSMutableArray arrayWithCapacity:array.count];
    for (id val in array) {
        id member = [self objectForAttribute:memberAttribute andClass:memberCls forMemberAttributeList:memberAttributeList andIndex:index + 1 withValue:val];
        if (member == nil)
            [object addObject:[NSNull null]];
        else
            [object addObject:member];
    }

    if (cls == [NSArray class] || cls == [NSMutableArray class])
        return object;

    return [[cls alloc] initWithArray:object copyItems:NO];
}

- (NSDictionary *)dictionaryForClass:(Class)cls ofMemberAttributeList:(NSArray *)memberAttributeList andIndex:(NSUInteger)index withValue:(id)value
{
    if (![[value class] isSubclassOfClass:[NSDictionary class]]) {
        if (value == [NSNull null])
            return nil;
        
        JDJsonDecoderWarning(@"expect NSDictionary subclass but %@, use empty one", NSStringFromClass([value class]));
        return [[cls alloc] init];
    }
    
    if (memberAttributeList.count <= index) {
        JDJsonDecoderWarning(@"member type of a dictionary not specified, use empty one");
        return [[cls alloc] init];
    }
    
    const char *memberAttribute = [memberAttributeList[index] pointerValue];
    Class memberCls = [self classFromPropertyAttribute:memberAttribute];
    
    NSDictionary *dictionary = value;
    NSMutableDictionary *object = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];
    for (NSString *key in dictionary) {
#ifdef DEBUG
        [self.keyPath addObject:key];
#endif
        id val = dictionary[key];
        id member = [self objectForAttribute:memberAttribute andClass:memberCls forMemberAttributeList:memberAttributeList andIndex:index + 1 withValue:val];
        if (member == nil)
            [object setObject:[NSNull null] forKey:key];
        else
            [object setObject:member forKey:key];
#ifdef DEBUG
        [self.keyPath removeLastObject];
#endif
    }

    if (cls == [NSDictionary class] || cls == [NSMutableDictionary class])
        return object;

    return [[cls alloc] initWithDictionary:object copyItems:NO];
}

- (NSString *)stringForClass:(Class)cls withValue:(id)value
{
    if (![[value class] isSubclassOfClass:[NSString class]]) {
        if (value == [NSNull null])
            return nil;
        
        JDJsonDecoderWarning(@"expect NSString subclass but %@, use empty one", NSStringFromClass([value class]));
        return [[cls alloc] init];
    }

    if (cls == [NSString class])
        return value;

    return [[cls alloc] initWithString:value];
}

- (NSNumber *)numberForClass:(Class)cls withValue:(id)value
{
    if (![[value class] isSubclassOfClass:[NSNumber class]]) {
        if (value == [NSNull null])
            return nil;
        
        JDJsonDecoderWarning(@"expect NSNumber subclass but %@, use @0", NSStringFromClass([value class]));
        return @0;
    }
    
    return value;
}

- (id)objectForPrimitiveType:(const char *)attribute withValue:(id)value
{
    if (![[value class] isSubclassOfClass:[NSNumber class]]) {
        if (value == [NSNull null])
            return @0;
        
        JDJsonDecoderWarning(@"expect NSNumber subclass but %@, use @0", NSStringFromClass([value class]));
        return @0;
    }
    
    const char *start = attribute + 1;
    size_t len = strcspn(start, ",");
    if (len == 0)
        return @0;

    return value;
}

#ifdef DEBUG
- (NSMutableArray *)keyPath
{
    if (_keyPath == nil)
        _keyPath = [[NSMutableArray alloc] init];
    
    return _keyPath;
}
#endif

@end
