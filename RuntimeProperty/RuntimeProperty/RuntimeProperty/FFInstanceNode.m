//
//  FFInstanceNode.m
//  RuntimeProperty
//
//  Created by Wesley Yang on 16/5/11.
//  Copyright © 2016年 ff. All rights reserved.
//
#import "FFPropertyInspector.h"
#ifdef FFPropertyInspectorOn

#import "FFInstanceNode.h"


@implementation FFInstanceNode

-(NSMutableDictionary *)userInfo
{
    if (!_userInfo) {
        _userInfo = [NSMutableDictionary dictionary];
    }
    return _userInfo;
}

-(NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@",self.instanceType,self.instanceName];
}

-(FFIVarNode *)ivarNamed:(NSString *)name
{
    for (FFIVarNode *ivar in self.ivars) {
        if ([ivar.instanceName isEqualToString:name]) {
            return ivar;
        }
    }
    return nil;
}

-(FFPropertyNode *)propertyNamed:(NSString *)name
{
    for (FFPropertyNode *prop in self.properties) {
        if ([prop.instanceName isEqualToString:name]) {
            return prop;
        }
    }
    return nil;
}

-(void)setRawValue:(id)rawValue
{
    _rawValue = rawValue;
    NSArray *supportedClassDesc = @[@"NSNumber",@"NSString"];

    for (NSString *cls in supportedClassDesc) {
        if([rawValue isKindOfClass:NSClassFromString(cls)]){
            _safeToUseRawValue = YES;
            break;
        }
    }

}


@end


@implementation FFPropertyNode

@end

@implementation FFIVarNode

@end

@implementation FFElementNode

@end

@implementation FFMethodNode

@end

#endif
