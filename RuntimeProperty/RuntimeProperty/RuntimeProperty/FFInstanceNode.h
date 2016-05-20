//
//  FFInstanceNode.h
//  RuntimeProperty
//
//  Created by Wesley Yang on 16/5/11.
//  Copyright © 2016年 ff. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FFPropertyNode,FFIVarNode;


@interface FFInstanceNode : NSObject

@property (nonatomic) id rawValue;
@property (nonatomic) BOOL rawValueValid;
@property (nonatomic) BOOL isObject;

@property (nonatomic) NSString *instanceName;
@property (nonatomic) NSString *instanceType;

@property (nonatomic)FFInstanceNode *superClassNode;
@property (nonatomic,weak) FFInstanceNode *inheritClassNode;

@property (nonatomic,weak) FFInstanceNode *parentNode;

@property (nonatomic,strong) NSArray<FFPropertyNode*> *properties;
@property (nonatomic,strong) NSArray<FFIVarNode*> *ivars;

@property (nonatomic) NSMutableDictionary *userInfo;

@property (nonatomic) int depth;
@end

@interface FFPropertyNode : FFInstanceNode


@end

@interface FFIVarNode : FFInstanceNode

@end


