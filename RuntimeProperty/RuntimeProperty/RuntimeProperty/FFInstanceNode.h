//
//  FFInstanceNode.h
//  RuntimeProperty
//
//  Created by Wesley Yang on 16/5/11.
//  Copyright © 2016年 ff. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFPropertyInspector.h"

#ifdef FFPropertyInspectorOn


@class FFPropertyNode,FFIVarNode,FFElementNode,FFMethodNode;


@interface FFInstanceNode : NSObject

/**
 *  rawValue: when isObject is true,this value is same as origin object, otherwise it is a NSValue object for int\BOOL\CGSize\CGRect...
 */
@property (nonatomic) id rawValue;
/**
 *  whether rawValue is a valid value
 */
@property (nonatomic) BOOL rawValueValid;
/**
 *  whether this property/iVar is an object
 */
@property (nonatomic) BOOL isObject;
/**
 *  name of this property/iVar on parent object
 */
@property (nonatomic) NSString *instanceName;
/**
 *  type of this instance
 */
@property (nonatomic) NSString *instanceType;
/**
 *  super class node
 */
@property (nonatomic)FFInstanceNode *superClassNode;
/**
 *  inherit class node
 */
@property (nonatomic,weak) FFInstanceNode *inheritClassNode;
/**
 *  parent node where this node is on
 */
@property (nonatomic,weak) FFInstanceNode *parentNode;
/**
 *  properties of this object
 */
@property (nonatomic,strong) NSArray<FFPropertyNode*> *properties;
/**
 *  ivars of this object
 */
@property (nonatomic,strong) NSArray<FFIVarNode*> *ivars;
/**
 *  elements of this object
 */
@property (nonatomic,strong) NSArray<FFElementNode*> *elements;
/**
 *  instance methods of this object
 */
@property (nonatomic,strong) NSArray<FFMethodNode*> *instanceMethods;
/**
 *  class methods of this object
 */
@property (nonatomic,strong) NSArray<FFMethodNode*> *classMethods;

@property (nonatomic,assign) BOOL safeToUseRawValue;
/**
 *  user defined infos
 */
@property (nonatomic) NSMutableDictionary *userInfo;
/**
 *  depth in parsing
 */
@property (nonatomic) int depth;

/**
 *  return an ivar with provided name
 *
 *  @param name ivar name
 *
 *  @return ivar node
 */
-(FFIVarNode*)ivarNamed:(NSString*)name;

/**
 *  return a property with provided name
 *
 *  @param name property name
 *
 *  @return property node
 */
-(FFPropertyNode *)propertyNamed:(NSString *)name;

@end

/**
 *  represent a property node
 */
@interface FFPropertyNode : FFInstanceNode


@end


/**
 *  represent a ivar node
 */
@interface FFIVarNode : FFInstanceNode

@end

/**
 *  represent an element of `Set/Array/Dic`
 */
@interface FFElementNode : FFInstanceNode

@end


@interface FFMethodNode : FFInstanceNode

@property (nonatomic) NSString *methodName;
@property (nonatomic) BOOL isClassMethod;
@end


#endif
