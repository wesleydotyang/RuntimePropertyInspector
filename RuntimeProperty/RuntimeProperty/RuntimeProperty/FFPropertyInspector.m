//
//  FFPropertyInspector.m
//  RuntimeProperty
//
//  Created by Wesley Yang on 16/5/10.
//  Copyright © 2016年 ff. All rights reserved.
//
#import "FFPropertyInspector.h"

#ifdef FFPropertyInspectorOn

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach/mach.h>
#import <malloc/malloc.h>
#import <time.h>


struct FFObjectStruct {
    Class isa_;
}FFObjectStruct;


static kern_return_t FFReadMemory(task_t task, vm_address_t address, vm_size_t size, void **data) {
    *data = (void*)address;
    return KERN_SUCCESS;
}

static Class* FFGetAllClassList(size_t *size)
{
    static Class * classes = NULL;
    static size_t classes_size = 0;
    
    if (classes != NULL) {
        *size = classes_size;
        return classes;
    }
    
    int numClasses = objc_getClassList(NULL, 0);
    classes_size = numClasses;
    *size = numClasses;

    if (numClasses > 0 )
    {
        classes = (Class*)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
    }
    return classes;
}


static Class* FFGetClassesMatchString(NSString *query,size_t *result_size)
{
    size_t size;
    Class *allClasses = FFGetAllClassList(&size);
    size_t maxClasses = 1000;
    Class *results = (Class*)malloc(sizeof(Class)*maxClasses);
    int count = 0;
    NSArray *blackList = @[@"NSAutoreleasePool",@"NSPlaceholderValue"];
    for (int i=0; i<size && count<maxClasses; ++i) {
        Class cls = allClasses[i];
        NSString *clsName = NSStringFromClass(cls);
        //debug print all classes
//        NSLog(@"Class:%@",clsName);

        if ([clsName rangeOfString:query].location != NSNotFound || query.length==0) {
            if ([blackList containsObject:clsName]) {
                continue;
            }
            if ([clsName hasPrefix:@"_"] || [clsName hasPrefix:@"FF"] || [clsName hasPrefix:@"NSCF"] || [clsName hasPrefix:@"NSTag"] || [clsName hasPrefix:@"CF"]) {
                continue;
            }
            
            results[count] = cls;
            count++;
        }
    }
    *result_size = count;
    
    return results;
}



typedef void (^ff_object_enumeration_block_t)(__unsafe_unretained id object, __unsafe_unretained Class actualClass,BOOL *stop);


static CFMutableSetRef ff_filter_classes;//store filter classes

static void FFChooseClass(ff_object_enumeration_block_t enumurator);

static NSArray* FFGetInstancesOfClassesMatchString(NSString* query){
    CFTimeInterval startTime = CACurrentMediaTime();
    NSString *lowercaseQuery = query.lowercaseString;
    size_t count;
    Class *filter_classes = FFGetClassesMatchString(query,&count);
    
    if (!ff_filter_classes) {
        ff_filter_classes = CFSetCreateMutable(NULL, 0, NULL);
    }else{
        CFSetRemoveAllValues(ff_filter_classes);
    }
    
    for (int i=0;i<count;++i) {
        Class cls = filter_classes[i];
        CFSetAddValue(ff_filter_classes, (__bridge const void *)cls);
    }
    
    free(filter_classes);
    
    int maxResult = 1000;
    __block int ff_result_instances_count = 0;
    void** ff_result_instances = (void**)malloc(sizeof(void*) * maxResult);
    
    FFChooseClass(^(__unsafe_unretained id object, __unsafe_unretained Class actualClass, BOOL *stop) {
        if (ff_result_instances_count>maxResult) {
            *stop = YES;
        }
        if([NSStringFromClass(actualClass).lowercaseString rangeOfString:lowercaseQuery].location!=NSNotFound){
            ff_result_instances[ff_result_instances_count++] = (__bridge void *)(object);
        }
    });
    
    NSLog(@"CostTime %dms",(int)((CACurrentMediaTime()-startTime)*1000));
    
    NSMutableArray *array = [NSMutableArray array];
    for (int i=0;i<ff_result_instances_count;++i) {
        void *obj = ff_result_instances[i];
        [array addObject:(__bridge id _Nonnull)(obj)];
    }
    free(ff_result_instances);
    return array;
}

static void FFRangesCallback(task_t task, void *baton, unsigned type,
                             vm_range_t *ranges, unsigned count) {
    ff_object_enumeration_block_t callback = (__bridge ff_object_enumeration_block_t)(baton);
    BOOL shouldStop = NO;
    
    for(int i=0;i<count;++i){
        vm_range_t range = ranges[i];
        void *data = (void *)range.address;
        size_t size = range.size;
        if (size < sizeof(FFObjectStruct))
            continue;
        
        uintptr_t *pointers = (uintptr_t *)range.address;
        void *ptr = (void*)(pointers[0] & 0x1fffffff8);
        Class isa = (__bridge Class)ptr;
        
        if (ptr == (void*)0x100000000) {
            continue;
        }
        
        if (!CFSetContainsValue(ff_filter_classes,(__bridge const void *)isa)) {
            continue;
        }
        
        
        size_t needed = class_getInstanceSize(isa);
        size_t boundary = 496;
#ifdef __LP64__
        boundary *= 2;
#endif
        if ((needed <= boundary && (needed + 15) / 16 * 16 != size) || (needed > boundary && (needed + 511) / 512 * 512 != size))
            continue;
        // Check the allocation size
        size_t allocated_size = malloc_size(data);
        size_t instance_size = class_getInstanceSize(isa);
        if (allocated_size < instance_size)
        {
            continue;
        }
        
        callback((__bridge id)(data),isa,&shouldStop);
        
        if (shouldStop) {
            break;
        }
    }
}

static void FFChooseClass(ff_object_enumeration_block_t enumurator)
{
    vm_address_t *zones;
    unsigned size;
    kern_return_t ret = malloc_get_all_zones(0,&FFReadMemory,&zones,&size);
    if (ret != KERN_SUCCESS) {
        return;
    }
    
    
    for (int i=0; i<size; ++i) {
        vm_address_t zoneAddress = zones[i];
        malloc_zone_t *zone = (malloc_zone_t*)zones[i];
        if (zone == NULL || zone->introspect == NULL)
            continue;
        
        @try {
            zone->introspect->force_lock(zone);
            zone->introspect->enumerator(mach_task_self(),(__bridge void *)(enumurator),MALLOC_PTR_IN_USE_RANGE_TYPE,zoneAddress,&FFReadMemory,FFRangesCallback);
        
            zone->introspect->force_unlock(zone);
        } @catch (NSException *exception) {
            
        }
        
    }
}


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

+(NSArray*)searchForInstancesOfClassMatch:(NSString *)match
{
    return FFGetInstancesOfClassesMatchString(match);
}

+(FFInstanceNode*)nodeDataForInstance:(NSObject*)instance;
{
    FFInstanceNode *rootNode = [[FFInstanceNode alloc] init];
    rootNode.rawValue = instance;
    rootNode.rawValueValid = YES;
    rootNode.instanceType = NSStringFromClass(instance.class);
    rootNode.instanceName = rootNode.instanceType;
    rootNode.isObject = YES;
    rootNode.depth = 0;
    
//    [self parsePropertiesForClass:instance.class withInstanceNode:rootNode];
    
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
            
            if ([instanceNode.rawValue isKindOfClass:[NSArray class]]) {
                [self parseArrayWithNode:instanceNode];
            }else if([instanceNode.rawValue isKindOfClass:[NSDictionary class]]){
                [self parseDictionaryWithNode:instanceNode];
            }else{
                [self parsePropertiesForClass:cls withInstanceNode:instanceNode];
                [self parseMethodsForClass:cls withNode:instanceNode];
                [self mergePropertyMethodForNode:instanceNode];

            }
        }
    }
    
}


+(void)parseDictionaryWithNode:(FFInstanceNode*)node
{
    NSDictionary *dic = node.rawValue;
    NSMutableArray *childNodes = [NSMutableArray array];
    
    [dic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        FFElementNode *inode = [[FFElementNode alloc] init];
        inode.rawValue = obj;
        inode.rawValueValid = YES;
        inode.instanceName = key;
        if ([obj isKindOfClass:[NSNumber class]]) {
            inode.instanceType = NSStringFromClass([NSNumber class]);
        }else if([obj isKindOfClass:[NSString class]]){
            inode.instanceType = NSStringFromClass([NSString class]);
        }else{
            inode.instanceType = NSStringFromClass([obj class]);
        }
        inode.isObject = YES;
        inode.parentNode = node;
        inode.depth = node.depth+1;
        [childNodes addObject:inode];
    }];

    
    node.elements = childNodes;
}

+(void)parseArrayWithNode:(FFInstanceNode*)node
{
    NSArray *array = node.rawValue;
    NSMutableArray *childNodes = [NSMutableArray array];

    for (int i=0;i<array.count;++i) {
        id obj = array[i];
        FFElementNode *inode = [[FFElementNode alloc] init];
        inode.rawValue = obj;
        inode.rawValueValid = YES;
        inode.instanceName = [NSString stringWithFormat:@"%d",i];
        if ([obj isKindOfClass:[NSNumber class]]) {
            inode.instanceType = NSStringFromClass([NSNumber class]);
        }else if([obj isKindOfClass:[NSString class]]){
            inode.instanceType = NSStringFromClass([NSString class]);
        }else{
            inode.instanceType = NSStringFromClass([obj class]);
        }
        inode.isObject = YES;
        inode.parentNode = node;
        inode.depth = node.depth+1;
        [childNodes addObject:inode];
    }
    
    node.elements = childNodes;
}



+(void)parseMethodsForClass:(Class)cls withNode:(FFInstanceNode*)node
{
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    NSMutableArray *instanceMethods = [NSMutableArray arrayWithCapacity:methodCount];
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        FFMethodNode *methodNode = [FFMethodNode new];
        methodNode.methodName = NSStringFromSelector(method_getName(method));
        methodNode.parentNode = node;
        methodNode.depth = node.depth+1;
        if ([methodNode.methodName hasPrefix:@"."]) {//hidden methods
            continue;
        }
        [instanceMethods addObject:methodNode];
    }
    
    free(methods);
    
    Method *cMethods = class_copyMethodList(object_getClass(cls), &methodCount);
    
    NSMutableArray *classMethods = [NSMutableArray arrayWithCapacity:methodCount];
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = cMethods[i];
        FFMethodNode *methodNode = [FFMethodNode new];
        methodNode.methodName = NSStringFromSelector(method_getName(method));
        methodNode.isClassMethod = YES;
        methodNode.depth = node.depth+1;
        [classMethods addObject:methodNode];
    }
    
    free(cMethods);
    
    
    node.instanceMethods = instanceMethods;
    node.classMethods = classMethods;
}

//http://stackoverflow.com/questions/29641396/how-to-get-and-set-a-property-value-with-runtime-in-objective-c
+(void)parsePropertiesForClass:(Class)cls withInstanceNode:(FFInstanceNode*)node
{

    if (!cls
        || cls==[NSObject class]
        || cls==[NSString class]
        || cls==[NSNumber class]
        || [cls isSubclassOfClass:[NSNumber class]]
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
                if(object){\
                ptrdiff_t offset = ivar_getOffset(var);\
                unsigned char *stuffBytes = (unsigned char *)(__bridge void *)object;\
                _type result = * ((_type *)(stuffBytes + offset));\
                inode.rawValue = [NSValue _methodName:result];\
                }\
                inode.rawValueValid = YES;\
                ivarTypeName = @#_type;\
        }
        
        switch (typeEncStart) {
            case '@':{
                id value = object_getIvar(object, var);
                inode.rawValue = value;
                inode.rawValueValid = YES;
                inode.isObject = YES;
                if (object_getClass(value)) {
                    ivarTypeName = NSStringFromClass(object_getClass(value));
                }else{
                    NSString *type = [NSString stringWithCString:typeEncoding encoding:NSASCIIStringEncoding];
                    if (type.length>3) {
                        ivarTypeName = [type substringWithRange:NSMakeRange(2, type.length-3)];
                    }else{
                        ivarTypeName = @"id";
                    }
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
                if (ivarTypeName==nil) {
                    NSLog(@"unHandeledStruct %@",typeString);
                }
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

+(void)mergePropertyMethodForNode:(FFInstanceNode*)node
{
    NSMutableArray *methodsFiltered = [NSMutableArray arrayWithArray:node.instanceMethods];
    for (FFMethodNode *methodNode in node.instanceMethods) {
        for (FFInstanceNode *propertyNode in node.properties) {
            NSString *propertyName = propertyNode.instanceName;
            NSString *firstLetter = [propertyName substringToIndex:1];
            NSString *otherLetter = [propertyName substringFromIndex:1];
            NSString *setterName = [NSString stringWithFormat:@"set%@%@:",firstLetter.capitalizedString,otherLetter];
            
            if ([propertyName isEqualToString:methodNode.methodName]
                || [setterName isEqualToString:methodNode.methodName]) {
                [methodsFiltered removeObject:methodNode];
                break;
            }
        }
    }
    node.instanceMethods = methodsFiltered;
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

+(BOOL)alterInstance:(FFInstanceNode *)instance toValue:(id)value
{
    if ([instance isKindOfClass:[FFPropertyNode class]]) {
        return [self alterProperty:(FFPropertyNode*)instance toValue:value];
    }else if([instance isKindOfClass:[FFIVarNode class]]){
        return [self alterIvar:(FFIVarNode*)instance toValue:value];
    }else if([instance isKindOfClass:[FFElementNode class]]){
        return [self alterElement:(FFElementNode*)instance toValue:value];
    }
    return NO;
}


+(BOOL)alterElement:(FFElementNode*)elementNode toValue:(id)newValue
{
    FFInstanceNode *parentNode = elementNode.parentNode;
    if ([parentNode.rawValue isKindOfClass:[NSMutableArray class]]) {
        NSMutableArray *array = parentNode.rawValue;
        [array replaceObjectAtIndex:[elementNode.instanceName intValue] withObject:newValue];
        elementNode.rawValue = newValue;
        elementNode.instanceType = NSStringFromClass([newValue class]);
        return YES;
    }else if([parentNode.rawValue isKindOfClass:[NSMutableDictionary class]]){
        NSMutableDictionary *dic = parentNode.rawValue;
        dic[elementNode.instanceName] = newValue;
        elementNode.rawValue = newValue;
        return YES;
    }
    return NO;
}

+(BOOL)alterProperty:(FFPropertyNode *)propertyNode toValue:(id)newValue
{
    FFInstanceNode *objectNode = propertyNode.parentNode;

    id obj = objectNode.rawValue;
    NSString *propertyName = propertyNode.instanceName;
    
    if (obj==nil || propertyName==nil || propertyName.length==0) {
        return NO;
    }
    
    Class class = object_getClass(obj);
    if (class == Nil) {
        return NO;
    }
    
    objc_property_t property = class_getProperty(class,[propertyName cStringUsingEncoding:NSASCIIStringEncoding]);
    SEL setter;
    const char* setterName = property_copyAttributeValue(property, "S");
    if (setterName==NULL)
    {
        NSString *firstLetter = [propertyName substringToIndex:1];
        NSString *otherLetter = [propertyName substringFromIndex:1];
        NSString *sName = [NSString stringWithFormat:@"set%@%@:",firstLetter.capitalizedString,otherLetter];
        setter = NSSelectorFromString(sName);
    }
    else
    {
        setter = sel_getUid(setterName);
    }
    
    
    @try {
        
        if (![obj respondsToSelector:setter]) {
            NSLog(@"does not support setter");
            return NO;
        }
        
        NSMethodSignature* sig = [obj methodSignatureForSelector:setter];
        if (sig) {

            NSInvocation *invoke = [NSInvocation invocationWithMethodSignature:sig];
            invoke.selector = setter;
            //get raw value
            if (propertyNode.isObject) {
                [invoke setArgument:&newValue atIndex:2];
            }else{
#define IF_TYPE_AND_SET_INVOKE(type,convert) \
if ([propertyNode.instanceType isEqualToString:@#type]) {\
    type raw = [newValue convert];\
    [invoke setArgument:&raw atIndex:2];\
}
                IF_TYPE_AND_SET_INVOKE(CGRect,CGRectValue)
                else IF_TYPE_AND_SET_INVOKE(BOOL,boolValue)
                else IF_TYPE_AND_SET_INVOKE(int,intValue)
                else IF_TYPE_AND_SET_INVOKE(unsigned int,unsignedIntValue)
                else IF_TYPE_AND_SET_INVOKE(float,floatValue)
                else IF_TYPE_AND_SET_INVOKE(double,doubleValue)
                else IF_TYPE_AND_SET_INVOKE(char,charValue)
                else IF_TYPE_AND_SET_INVOKE(unsigned char,unsignedCharValue)
                else return NO;
                
                if ([propertyNode.instanceType isEqualToString:@"CGRect"]) {
                    CGRect raw = [newValue CGRectValue];
                    [invoke setArgument:&raw atIndex:2];
                }else if([propertyNode.instanceType isEqualToString:@"BOOL"]){
                    BOOL raw = [newValue boolValue];
                    [invoke setArgument:&raw atIndex:2];
                }else if([propertyNode.instanceType isEqualToString:@"int"]){
                    int raw = [newValue intValue];
                    [invoke setArgument:&raw atIndex:2];
                }else{
                    return NO;
                }
            }
            [invoke invokeWithTarget:obj];
            
            propertyNode.rawValue = newValue;
            return YES;
        }else{
            NSLog(@"sig nil for %@",propertyName);
        }
        return NO;
        
    } @catch (NSException *exception) {
        return NO;
    } @finally {
        
    }

    
    return NO;
}

+(BOOL)alterIvar:(FFIVarNode*)ivar toValue:(id)value
{
    FFInstanceNode *objectNode = ivar.parentNode;
    
    if (!objectNode || !ivar) {
        return NO;
    }
    
    @try {
        [objectNode.rawValue setValue:value forKey:ivar.instanceName];
        ivar.rawValue = value;
    } @catch (NSException *exception) {
        NSLog(@"%@",exception.description);
        return NO;
    } @finally {
    }
    return YES;
}



@end


#endif
