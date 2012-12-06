//
//  JDJsonDecoder.m
//  JDJsonDecoder
//
//  Created by Eungkyu Song on 12. 12. 4..
//  Copyright (c) 2012년 Ticketmonster, Inc. All rights reserved.
//

#import "JDJsonDecoder.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        *error = [NSError errorWithDomain:JDJsonDecoderErrorDomain code:JDJsonDecoderErrorNotDictionary userInfo:@{NSLocalizedDescriptionKey : @"Top level of JSONObject must be a dictionary"}];
        return nil;
    }
    
    return [[[self alloc] init] objectForClass:cls withValue:jsonObject];
}

static NSMutableDictionary *classHandlerMap;

+ (void)registerHandler:(id<JDJsonDecoding>)classHandler forClass:(Class)cls
{
    if (classHandlerMap == nil)
        classHandlerMap = [NSMutableDictionary dictionaryWithCapacity:1];
    
    [classHandlerMap setObject:classHandler forKey:[NSValue valueWithNonretainedObject:cls]];
}

- (id)objectForClass:(Class)cls withValue:(id)value
{
    if (![value isKindOfClass:[NSDictionary class]]) {
        if (value == [NSNull null])
            return nil;
        
        NSLog(@"not a dictionary, use empty object");
        return [[cls alloc] init];
    }
    
    id object = [[cls alloc] init];
    NSDictionary *dic = value;
    for (NSString *key in dic) {
        id val = dic[key];
    
        objc_property_t property = class_getProperty(cls, [key cStringUsingEncoding:NSUTF8StringEncoding]);
        if (property == NULL) {
            NSLog(@"%@: no property, ignoring", key);
            continue;
        }
        const char *attribute = property_getAttributes(property);
        Class propertyCls = [self classFromPropertyAttribute:attribute];
        NSMutableArray *memberAttributeList = nil;
        if ([propertyCls isSubclassOfClass:[NSArray class]] || [propertyCls isSubclassOfClass:[NSDictionary class]]) {
            memberAttributeList = [self memberAttributeListIn:cls forProperty:property named:key];
        }
        
        id member = [self objectForAttribute:attribute andClass:propertyCls forMemberAttributeList:memberAttributeList fromValue:val];
        
        @try {
            [object setValue:member forKey:key];
        }
        @catch (NSException *exception) {
            NSLog(@"%@: no property setter, ignoring", key);
        }
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
    
    if (len >= 32)
        free(ptr);
    
    return objc_getClass(ptr);
}

- (id)objectForAttribute:(const char *)attribute andClass:(Class)cls forMemberAttributeList:(NSMutableArray *)memberAttributeList fromValue:(id)value
{
    if ([cls isSubclassOfClass:[NSArray class]])
        return [self arrayForClass:cls ofMemberAttributeList:memberAttributeList withValue:value];
    
    if ([cls isSubclassOfClass:[NSDictionary class]])
        return [self dictionaryForClass:cls ofMemberAttributeList:memberAttributeList withValue:value];
    
    if (classHandlerMap != nil) {
        for (NSValue *key in classHandlerMap) {
            if (cls == [key nonretainedObjectValue])
                return [classHandlerMap[key] objectWithValue:value];
        }
    }
    
    if ([cls isSubclassOfClass:[NSString class]])
        return [self stringForClass:cls withValue:value];
    
    if ([cls isSubclassOfClass:[NSNumber class]])
        return [self numberForClass:cls withValue:value];

    if (cls == nil)
        return [self objectForAttribute:attribute fromValue:value];
    
    return nil;
}

- (id)arrayForClass:(Class)cls ofMemberAttributeList:(NSMutableArray *)memberAttributeList withValue:(id)value
{
    if (![[value class] isSubclassOfClass:[NSArray class]]) {
        if (value == [NSNull null])
            return nil;
        
        NSLog(@"not an array, use empty one");
        return [[cls alloc] init];
    }
    
    if (memberAttributeList.count == 0) {
        NSLog(@"member type of an array not specified, use empty one");
        return [[cls alloc] init];
    }
    
    const char *memberAttribute = [memberAttributeList[0] pointerValue];
    [memberAttributeList removeObjectAtIndex:0];
    Class memberCls = [self classFromPropertyAttribute:memberAttribute];
    
    NSArray *array = value;
    NSMutableArray *object = [NSMutableArray arrayWithCapacity:array.count];
    for (id val in array) {
        id member = [self objectForAttribute:memberAttribute andClass:memberCls forMemberAttributeList:memberAttributeList fromValue:val];
        if (member == nil)
            [object addObject:[NSNull null]];
        else
            [object addObject:member];
    }
    
    return [[cls alloc] initWithArray:object copyItems:NO];
}

- (NSDictionary *)dictionaryForClass:(Class)cls ofMemberAttributeList:(NSMutableArray *)memberAttributeList withValue:(id)value
{
    if (![[value class] isSubclassOfClass:[NSDictionary class]]) {
        if (value == [NSNull null])
            return nil;
        
        NSLog(@"not a dictionary, use empty one");
        return [[cls alloc] init];
    }
    
    if (memberAttributeList.count == 0) {
        NSLog(@"member type of a dictionary not specified, use empty one");
        return [[cls alloc] init];
    }
    
    const char *memberAttribute = [memberAttributeList[0] pointerValue];
    [memberAttributeList removeObjectAtIndex:0];
    Class memberCls = [self classFromPropertyAttribute:memberAttribute];
    
    NSDictionary *dictionary = value;
    NSMutableDictionary *object = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];
    for (NSString *key in dictionary) {
        id val = dictionary[key];
        id member = [self objectForAttribute:memberAttribute andClass:memberCls forMemberAttributeList:memberAttributeList fromValue:val];
        if (member == nil)
            [object setObject:[NSNull null] forKey:key];
        else
            [object setObject:member forKey:key];
    }
    
    return object;
}

- (NSString *)stringForClass:(Class)cls withValue:(id)value
{
    if (![[value class] isSubclassOfClass:[NSString class]]) {
        if (value == [NSNull null])
            return nil;
        
        NSLog(@"not a string, use empty one");
        return [[cls alloc] init];
    }

    return [[cls alloc] initWithString:value];
}

- (NSNumber *)numberForClass:(Class)cls withValue:(id)value
{
    if (![[value class] isSubclassOfClass:[NSNumber class]]) {
        if (value == [NSNull null])
            return nil;
        
        NSLog(@"not a number, use 0");
        return @0;
    }
    
    return value;
}

- (id)objectForAttribute:(const char *)attribute fromValue:(id)value
{
    if (![[value class] isSubclassOfClass:[NSNumber class]]) {
        if (value == [NSNull null])
            return nil;
        
        NSLog(@"not a number, use 0");
        return @0;
    }
    
    const char *start = attribute + 1;
    size_t len = strcspn(start, ",");
    if (len == 0)
        return nil;

    return value;
}

@end