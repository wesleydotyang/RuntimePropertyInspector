//
//  RuntimePropertyTests.m
//  RuntimePropertyTests
//
//  Created by Wesley Yang on 16/5/10.
//  Copyright © 2016年 ff. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FFPropertyInspector.h"

@interface TestingObject : NSObject
{
    @public
    BOOL testBOOL;
    CGSize testSize;
}
@property (nonatomic) id p_obj;
@property (nonatomic) BOOL pBOOL;
@property (nonatomic) CGRect pRect;
@property (nonatomic) int pInt;

@end

@implementation TestingObject
@end

@interface RuntimePropertyTests : XCTestCase

@end

@implementation RuntimePropertyTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testCase {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    TestingObject *obj = [TestingObject new];
    obj->testBOOL = YES;
    obj.p_obj = [UIImage new];

    FFInstanceNode *node;
    //inspect BOOL ivar
    node = [FFPropertyInspector nodeDataForInstance:obj];
    FFInstanceNode *retNode = [node  ivarNamed:@"testBOOL"];
    XCTAssertNotNil(retNode);
    XCTAssertEqual(retNode.rawValue, @YES);
    XCTAssertEqualObjects(retNode.instanceType, @"BOOL");
    
    //alter BOOL ivar
    [FFPropertyInspector alterIvar:(FFIVarNode*)retNode toValue:@NO];
    XCTAssertEqual(retNode.rawValue,@NO);
    XCTAssertTrue(obj->testBOOL==NO);
    
    
    node = [FFPropertyInspector nodeDataForInstance:obj];
    retNode = [node  ivarNamed:@"testSize"];
    XCTAssertNotNil(retNode);
    XCTAssertTrue(CGSizeEqualToSize([retNode.rawValue CGSizeValue] ,CGSizeMake(0, 0)));
    XCTAssertEqualObjects(retNode.instanceType, @"CGSize");
    
    obj->testSize = CGSizeMake(100, 101);
    node = [FFPropertyInspector nodeDataForInstance:obj];
    retNode = [node  ivarNamed:@"testSize"];
    XCTAssertNotNil(retNode);
    XCTAssertTrue(CGSizeEqualToSize([retNode.rawValue CGSizeValue] ,obj->testSize));

    /**
     *  PROPERTY Test
     */
    //BOOL test
    obj.pBOOL = YES;
    node = [FFPropertyInspector nodeDataForInstance:obj];
    retNode = [node propertyNamed:@"pBOOL"];
    XCTAssertNotNil(retNode);
    XCTAssertEqual(retNode.rawValue,@YES);
    XCTAssertEqualObjects(retNode.instanceType, @"BOOL");
    //alter BOOL
    [FFPropertyInspector alterProperty:(FFPropertyNode*)retNode toValue:@NO];
    XCTAssertTrue(obj.pBOOL==NO);
    
    //CGRect test
    obj.pRect = CGRectMake(0, 0, 100, 100);
    node = [FFPropertyInspector nodeDataForInstance:obj];
    retNode = [node propertyNamed:@"pRect"];
    XCTAssertNotNil(retNode);
    XCTAssertTrue(CGRectEqualToRect(obj.pRect, [retNode.rawValue CGRectValue]));
    XCTAssertEqualObjects(retNode.instanceType, @"CGRect");
    XCTAssertEqualObjects(retNode.instanceName, @"pRect");
    //alter cgrect
    CGRect newRect = CGRectMake(-1, 1, 10, 12);
    [FFPropertyInspector alterProperty:(FFPropertyNode*)retNode toValue:[NSValue valueWithCGRect:newRect]];
    XCTAssertTrue(CGRectEqualToRect(newRect, obj.pRect));
    XCTAssertTrue(CGRectEqualToRect(newRect, [retNode.rawValue CGRectValue]));

    
    //int test
    obj.pInt = 99;
    node = [FFPropertyInspector nodeDataForInstance:obj];
    retNode = [node propertyNamed:@"pInt"];
    XCTAssertNotNil(retNode);
    XCTAssertEqual(retNode.rawValue, @(obj.pInt));
    XCTAssertEqualObjects(retNode.instanceType, @"int");
    XCTAssertEqualObjects(retNode.instanceName, @"pInt");
    //alter int
    int newInt = 100;
    [FFPropertyInspector alterProperty:(FFPropertyNode*)retNode toValue:@(newInt)];
    XCTAssertTrue(newInt==obj.pInt);
    
    //object test
    retNode = [node propertyNamed:@"p_obj"];
    XCTAssertNotNil(retNode);
    XCTAssertEqual(retNode.rawValue,obj.p_obj);
    id newVal = [UIView new];
    [FFPropertyInspector alterProperty:(FFPropertyNode*)retNode toValue:newVal];
    XCTAssertEqual(obj.p_obj, newVal);

}




@end
