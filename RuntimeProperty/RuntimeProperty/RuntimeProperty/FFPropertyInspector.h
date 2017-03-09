//
//  FFPropertyInspector.h
//  RuntimeProperty
//
//  Created by Wesley Yang on 16/5/10.
//  Copyright © 2016年 ff. All rights reserved.
//

//main code switch
#define FFPropertyInspectorOn


#ifdef FFPropertyInspectorOn

#import <Foundation/Foundation.h>
#import "FFInstanceNode.h"

@interface FFPropertyInspector : NSObject

+(FFInstanceNode*)nodeDataForInstance:(NSObject*)instance;
+(void)expandInstanceNode:(FFInstanceNode*)instanceNode;

+(BOOL)alterInstance:(FFInstanceNode*)instance toValue:(id)value;

//alter property value
+(BOOL)alterProperty:(FFPropertyNode*)property toValue:(id)value;

//alter ivar value
+(BOOL)alterIvar:(FFIVarNode*)ivar toValue:(id)value;


+(NSArray<NSValue*>*)searchForInstancesOfClassMatch:(NSString *)match;

@end

#endif
