//
//  FFPropertyInspector.m
//  RuntimeProperty
//
//  Created by Wesley Yang on 16/5/10.
//  Copyright © 2016年 ff. All rights reserved.
//

#import "FFPropertyInspector.h"
@import UIKit;
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *extractStructName(NSString *typeEncodeString)
{
    NSArray *array = [typeEncodeString componentsSeparatedByString:@"="];
    NSString *typeString = array[0];
    int firstValidIndex = 0;
    for (int i = 0; i< typeString.length; i++) {
        char c = [typeString characterAtIndex:i];
        if (c == '{' || c=='_') {
            firstValidIndex++;
        }else {
            break;
        }
    }
    return [typeString substringFromIndex:firstValidIndex];
}

@implementation FFPropertyInspector



+(FFInstanceNode*)nodeDataForInstance:(NSObject*)instance;
{
    FFInstanceNode *rootNode = [[FFInstanceNode alloc] init];
    rootNode.rawValue = instance;
    rootNode.rawValueValid = YES;
    rootNode.instanceType = NSStringFromClass(instance.class);
    rootNode.instanceName = rootNode.instanceType;
    rootNode.isObject = YES;
    rootNode.depth = 0;
    
    [self parsePropertiesForClass:instance.class withInstanceNode:rootNode];
    
    // Return immutable.
    return rootNode;
}

+(void)expandInstanceNode:(FFInstanceNode*)instanceNode
{
    if (instanceNode.isObject) {
        Class cls = nil;
        if (instanceNode.inheritClassNode || instanceNode.rawValue==nil) {//this is a super node,or no rawValue
            cls = NSClassFromString(instanceNode.instanceType);
        }else{
            cls = [instanceNode.rawValue class];
        }
        
        if (cls) {
            [self parsePropertiesForClass:cls withInstanceNode:instanceNode];
        }
    }
    
}

//http://stackoverflow.com/questions/29641396/how-to-get-and-set-a-property-value-with-runtime-in-objective-c
+(void)parsePropertiesForClass:(Class)cls withInstanceNode:(FFInstanceNode*)node
{

    if (!cls
        || cls==[NSObject class]
        || cls==[NSString class]
        || cls==[NSNumber class]
        || cls==NSClassFromString(@"UIResponder")
        ) {
        return;
    }
    NSLog(@"parse %@",NSStringFromClass(cls));

    id object = node.rawValue;
    
    NSMutableArray *childPropertiesNode = [NSMutableArray array];
    
    //super class
    Class superCls = [cls superclass];
    if (superCls) {
        FFInstanceNode *superNode = [[FFInstanceNode alloc] init];
        superNode.rawValue = node.rawValue;
        superNode.rawValueValid = node.rawValueValid;
        superNode.instanceType = NSStringFromClass(superCls);
        superNode.instanceName = superNode.instanceType;
        superNode.isObject = YES;
        superNode.inheritClassNode = node;
        superNode.depth = node.depth+1;
        superNode.parentNode = node;
        node.superClassNode = superNode;
        [self parsePropertiesForClass:superCls withInstanceNode:superNode];
    }
    
    // Collect for this class.
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    for (int index = 0; index < propertyCount; index++)
    {
        NSString *propertyName = [NSString stringWithUTF8String:property_getName(properties[index])];
        BOOL isclass;
        NSString *propertyType = [self typeOfPropertyNamed:propertyName forClass:cls isClass:&isclass];
        FFPropertyNode *inode = [[FFPropertyNode alloc] init];
        BOOL isValid;
        inode.rawValue = [self valueForObj:object forPropertyNamedKey:propertyName isReturnValid:&isValid];
        inode.rawValueValid = isValid;
        inode.instanceName = propertyName;
        inode.instanceType = propertyType;
        inode.isObject = isclass;
        inode.parentNode = node;
        inode.depth = node.depth+1;
        [childPropertiesNode addObject:inode];
    }
    
    free(properties); // As it is a copy
    node.properties = childPropertiesNode;
    
    
    NSMutableArray *childIvarsNode = [NSMutableArray array];
    
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList(cls,&ivarCount);
    for (int i=0;i<ivarCount;++i) {
        FFIVarNode *inode = [[FFIVarNode alloc] init];

        Ivar var = ivars[i];
        const char *ivarName = ivar_getName(var);
        const char* typeEncoding = ivar_getTypeEncoding(var);
        NSLog(@"typeEncoding %s",typeEncoding);

        char typeEncStart = typeEncoding[0];
        if(typeEncoding[0]=='r'){typeEncStart = typeEncoding[1];}
        
        NSString *ivarTypeName = nil;
        
        #define CASE_OF_TYPE(_typeString, _type) \
        case _typeString: {                              \
        _type tempResultSet = ((_type (*)(id, Ivar))object_getIvar)(object, var);\
        inode.rawValue = @(tempResultSet);\
        inode.rawValueValid = YES;\
        ivarTypeName = @#_type;\
        break; \
        }
        
        #define IF_STRUCT_OF_TYPE(_type, _methodName) \
        if ([typeString isEqualToString:@#_type]) {\
                ptrdiff_t offset = ivar_getOffset(var);\
                unsigned char *stuffBytes = (unsigned char *)(__bridge void *)object;\
                _type result = * ((_type *)(stuffBytes + offset));\
                inode.rawValue = [NSValue _methodName:result];\
                inode.rawValueValid = YES;\
                ivarTypeName = @#_type;\
        }
        
        switch (typeEncStart) {
            case '@':{
                id value = object_getIvar(object, var);
                inode.rawValue = value;
                inode.rawValueValid = YES;
                if (object_getClass(value)) {
                    ivarTypeName = NSStringFromClass(object_getClass(value));
                    inode.isObject = YES;
                }
            }
                break;
            CASE_OF_TYPE('c', char)
            CASE_OF_TYPE('C', unsigned char)
            CASE_OF_TYPE('s', short)
            CASE_OF_TYPE('S', unsigned short)
            CASE_OF_TYPE('i', int)
            CASE_OF_TYPE('I', unsigned int)
            CASE_OF_TYPE('l', long)
            CASE_OF_TYPE('L', unsigned long)
            CASE_OF_TYPE('q', long long)
            CASE_OF_TYPE('Q', unsigned long long)
            CASE_OF_TYPE('f', float)
            CASE_OF_TYPE('d', double)
            CASE_OF_TYPE('B', BOOL)
            case '{': {
                
                NSString *typeString = extractStructName([NSString stringWithUTF8String:typeEncoding]);

                IF_STRUCT_OF_TYPE(CGRect,valueWithCGRect)
                IF_STRUCT_OF_TYPE(CGPoint,valueWithCGPoint)
                IF_STRUCT_OF_TYPE(CGSize,valueWithCGSize)
                IF_STRUCT_OF_TYPE(NSRange,valueWithRange)
                NSLog(@"unHandeledStruct %@",typeString);
                break;
            }
            case 'v':
            case '*':
            case '^'://pointer
            case '#': //Class

            default:
                break;
        }
        if (inode.rawValueValid == NO) {
            continue;
        }
        inode.instanceName = [NSString stringWithCString:ivarName encoding:NSASCIIStringEncoding];
        inode.instanceType = ivarTypeName;
        inode.parentNode = node;
        inode.depth = node.depth+1;
        [childIvarsNode addObject:inode];
    }
    free(ivars);
    node.ivars = childIvarsNode;

    [self mergePropertyIvarForNode:node];
    
}

+(void)mergePropertyIvarForNode:(FFInstanceNode*)node
{
    NSMutableArray *ivarsFiltered = [NSMutableArray arrayWithArray:node.ivars];
    for (FFInstanceNode *ivarNode in node.ivars) {
        for (FFInstanceNode *propertyNode in node.properties) {
            if ([[@"_" stringByAppendingString:propertyNode.instanceName] isEqualToString:ivarNode.instanceName]) {
                [ivarsFiltered removeObject:ivarNode];
                break;
            }
            
        }
    }
    node.ivars = ivarsFiltered;
    
}

+(id)valueForObj:(id)obj forPropertyNamedKey:(NSString*)propertyName isReturnValid:(BOOL*)isReturnValid
{

    if (obj==nil || propertyName==nil || propertyName.length==0) {
        return nil;
    }
    
    if ([propertyName hasPrefix:@"_"]) {
        return nil;
    }
    
    Class class = object_getClass(obj);
 
    
    objc_property_t property = class_getProperty(class,[propertyName cStringUsingEncoding:NSASCIIStringEncoding]);
    SEL getter;
    const char* getterName = property_copyAttributeValue(property, "G");
    if (getterName==NULL)
    {
        getter = NSSelectorFromString( propertyName );
    }
    else
    {
        getter = sel_getUid(getterName);
    }

    
    @try {
        *isReturnValid = NO;
        
        if (![obj respondsToSelector:getter]) {
            return nil;
        }
        
        NSMethodSignature* sig = [obj methodSignatureForSelector:getter];
        if (sig) {
            NSInvocation *invoke = [NSInvocation invocationWithMethodSignature:sig];
            invoke.selector = getter;
            [invoke invokeWithTarget:obj];
            id result = [self getReturnValueForInvocation:invoke isReturnValid:isReturnValid];
            return result;
        }else{
            NSLog(@"sig nil for %@",propertyName);
        }
        return nil;

    } @catch (NSException *exception) {
        return nil;
    } @finally {
        
    }

}

#define IF_CALL_RET_STRUCT(_type, _methodName) \
if ([typeString rangeOfString:@#_type].location != NSNotFound) {    \
_type resultA;   \
[invocation getReturnValue:&resultA];    \
return [NSValue _methodName:resultA];    \
}

#define IV_CASE_OF_TYPE(_typeString, _type) \
case _typeString: {                              \
_type tempResultSet; \
[invocation getReturnValue:&tempResultSet];\
returnValue = @(tempResultSet); \
break; \
}

+(id)getReturnValueForInvocation:(NSInvocation*)invocation isReturnValid:(BOOL*)isValidReturn{
    NSMethodSignature *methodSignature = invocation.methodSignature;
    NSString *selectorName = NSStringFromSelector(invocation.selector);
    const char *returnType = [methodSignature methodReturnType];
    id returnValue;
    *isValidReturn = YES;
    if (strncmp(returnType, "v", 1) != 0) {
        if (strncmp(returnType, "@", 1) == 0) {
            void *result;
            [invocation getReturnValue:&result];
            
            //For performance, ignore the other methods prefix with alloc/new/copy/mutableCopy
            if ([selectorName isEqualToString:@"alloc"] || [selectorName isEqualToString:@"new"] ||
                [selectorName isEqualToString:@"copy"] || [selectorName isEqualToString:@"mutableCopy"]) {
                returnValue = (__bridge_transfer id)result;
            } else {
                returnValue = (__bridge id)result;
            }
            return returnValue;
            
        } else {
            switch (returnType[0] == 'r' ? returnType[1] : returnType[0]) {
                    
                    IV_CASE_OF_TYPE('c', char)
                    IV_CASE_OF_TYPE('C', unsigned char)
                    IV_CASE_OF_TYPE('s', short)
                    IV_CASE_OF_TYPE('S', unsigned short)
                    IV_CASE_OF_TYPE('i', int)
                    IV_CASE_OF_TYPE('I', unsigned int)
                    IV_CASE_OF_TYPE('l', long)
                    IV_CASE_OF_TYPE('L', unsigned long)
                    IV_CASE_OF_TYPE('q', long long)
                    IV_CASE_OF_TYPE('Q', unsigned long long)
                    IV_CASE_OF_TYPE('f', float)
                    IV_CASE_OF_TYPE('d', double)
                    IV_CASE_OF_TYPE('B', BOOL)
                    
                case '{': {
                    NSString *typeString = extractStructName([NSString stringWithUTF8String:returnType]);

                    IF_CALL_RET_STRUCT(CGRect,valueWithCGRect)
                    IF_CALL_RET_STRUCT(CGPoint,valueWithCGPoint)
                    IF_CALL_RET_STRUCT(CGSize,valueWithCGSize)
                    IF_CALL_RET_STRUCT(NSRange,valueWithRange)
                    NSLog(@"unHandeledStruct %@",typeString);
                    *isValidReturn = NO;
                    return nil;
                    break;
                }
                case '*':
                case '^': {//pointer
                    *isValidReturn = NO;
                    return nil;
                }
                case '#': {//Class
                    *isValidReturn = NO;
                    return nil;
                }
            }
            return returnValue;
        }
    }
    *isValidReturn = NO;
    return nil;
}



+(NSString*)typeOfPropertyNamed:(NSString*) propertyName forClass:(Class)class isClass:(BOOL*)isClass
{
    NSString *propertyType = nil;
    NSString *propertyAttributes;
    
    // Get Class of property.
    objc_property_t property = class_getProperty(class, [propertyName UTF8String]);
    
    // Try to get getter method.
    if (property == NULL)
    {
        char typeCString[256];
        Method getter = class_getInstanceMethod(class, NSSelectorFromString(propertyName));
        method_getReturnType(getter, typeCString, 256);
        propertyAttributes = [NSString stringWithCString:typeCString encoding:NSUTF8StringEncoding];
        
        // Mimic type encoding for `typeNameForTypeEncoding:`.
        propertyType = [self typeNameForTypeEncoding:[NSString stringWithFormat:@"T%@", propertyAttributes]];
        
        if (getter == NULL)
        { NSLog(@"No property called `%@` of %@", propertyName, NSStringFromClass(class)); }
    }
    
    // Or go on with property attribute parsing.
    else
    {
        // Get property attributes.
        const char *propertyAttributesCString;
        propertyAttributesCString = property_getAttributes(property);
        propertyAttributes = [NSString stringWithCString:propertyAttributesCString encoding:NSUTF8StringEncoding];
        
        if (propertyAttributesCString == NULL)
        { NSLog(@"Could not get attributes for property called `%@` of <%@>", propertyName, NSStringFromClass(class)); }
        
        // Parse property attributes.
        NSArray *splitPropertyAttributes = [propertyAttributes componentsSeparatedByString:@","];
        if (splitPropertyAttributes.count > 0)
        {
            // From Objective-C Runtime Programming Guide.
            // xcdoc://ios//library/prerelease/ios/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
            NSString *encodeType = splitPropertyAttributes[0];
            NSArray *splitEncodeType = [encodeType componentsSeparatedByString:@"\""];
            *isClass = ([[splitEncodeType firstObject] isEqualToString:@"T@"]);
            propertyType = (splitEncodeType.count > 1) ? splitEncodeType[1] : [self typeNameForTypeEncoding:encodeType];
        }
        else
        { NSLog(@"Could not parse attributes for property called `%@` of <%@>å", propertyName, NSStringFromClass(class)); }
    }
    
    return propertyType;
}

+(NSString*)typeNameForTypeEncoding:(NSString*) typeEncoding
{
    // From Objective-C Runtime Programming Guide.
    // xcdoc://ios//library/prerelease/ios/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
    NSDictionary *typeNamesForTypeEncodings = @{
                                                
                                                @"Tc" : @"char",
                                                @"Ti" : @"int",
                                                @"Ts" : @"short",
                                                @"Tl" : @"long",
                                                @"Tq" : @"long long",
                                                @"TC" : @"unsigned char",
                                                @"TI" : @"unsigned int",
                                                @"TS" : @"unsigned short",
                                                @"TL" : @"unsigned long",
                                                @"TQ" : @"unsigned long long",
                                                @"Tf" : @"float",
                                                @"Td" : @"double",
                                                @"Tv" : @"void",
                                                @"T^v" : @"void*",
                                                @"T*" : @"char*",
                                                @"T@" : @"id",
                                                @"T#" : @"Class",
                                                @"T:" : @"SEL",
                                                
                                                @"T^c" : @"char*",
                                                @"T^i" : @"int*",
                                                @"T^s" : @"short*",
                                                @"T^l" : @"long*",
                                                @"T^q" : @"long long*",
                                                @"T^C" : @"unsigned char*",
                                                @"T^I" : @"unsigned int*",
                                                @"T^S" : @"unsigned short*",
                                                @"T^L" : @"unsigned long*",
                                                @"T^Q" : @"unsigned long long*",
                                                @"T^f" : @"float*",
                                                @"T^d" : @"double*",
                                                @"T^v" : @"void*",
                                                @"T^*" : @"char**",
                                                
                                                
                                                @"TB" : @"BOOL",
                                                @"T@?": @"BLOCK"
                                                };
    
    // Recognized format.
    if ([[typeNamesForTypeEncodings allKeys] containsObject:typeEncoding])
    { return [typeNamesForTypeEncodings objectForKey:typeEncoding]; }
    
    // Struct property.
    if ([typeEncoding hasPrefix:@"T{"])
    {
        // Try to get struct name.
        NSCharacterSet *delimiters = [NSCharacterSet characterSetWithCharactersInString:@"{="];
        NSArray *components = [typeEncoding componentsSeparatedByCharactersInSet:delimiters];
        NSString *structName;
        if (components.count > 1)
        { structName = components[1]; }
        
        // Falls back to `struct` when unknown name encountered.
        if ([structName isEqualToString:@"?"]) structName = @"struct";
        
        return structName;
    }
    
    // Falls back to raw encoding if none of the above.
    return typeEncoding;
}

@end

