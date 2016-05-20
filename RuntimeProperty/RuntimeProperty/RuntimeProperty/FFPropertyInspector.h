//
//  FFPropertyInspector.h
//  RuntimeProperty
//
//  Created by Wesley Yang on 16/5/10.
//  Copyright © 2016年 ff. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFInstanceNode.h"

@interface FFPropertyInspector : NSObject

+(FFInstanceNode*)nodeDataForInstance:(NSObject*)instance;
+(void)expandInstanceNode:(FFInstanceNode*)instanceNode;

+(void)parsePropertiesForClass:(Class)cls withInstanceNode:(FFInstanceNode*)node;
+(id)getReturnValueForInvocation:(NSInvocation*)invocation isReturnValid:(BOOL*)isValidReturn;
+(id)valueForObj:(id)obj  forPropertyNamedKey:(NSString*)propertyName isReturnValid:(BOOL*)isReturnValid;


@end
