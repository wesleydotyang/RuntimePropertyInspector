//
//  ViewController.m
//  RuntimeProperty
//
//  Created by Wesley Yang on 16/5/10.
//  Copyright © 2016年 ff. All rights reserved.
//

#import "ViewController.h"
#import "FFPropertyInspectView.h"
#import "FFPropertyInspector.h"
#import "AppDelegate.h"
#import <objc/runtime.h>

@interface TestObject : NSObject
{
    @public
    FFPropertyInspectView *inspectView;
    int testInt;
    CGRect testRect;
    CGSize _testSize;

}
//@property (weak, nonatomic)  FFPropertyInspectView *inspectView;
@property (nonatomic) UIImage *image;
@property (nonatomic) CGRect rect;
@property (nonatomic) CATransform3D transform;
@property (nonatomic) NSArray *testArray;
@property (nonatomic) NSString *testStr;

@end

@implementation TestObject


@end



@interface ViewController (){
}
@property (weak, nonatomic) IBOutlet FFPropertyInspectView *inspectView;
@property (nonatomic,strong) NSDictionary *testDic;

@property (nonatomic) CGRect rect;

@end

@implementation ViewController



- (void)viewDidLoad {
    [super viewDidLoad];
//    [self.class test];

    TestObject *testObj = [TestObject new];
//    testObj->testRect = CGRectMake(1, 1, 2, 3);
    testObj.rect = CGRectMake(0, 1, 2, 3);
    testObj.testArray = @[@4,@1,@2];
    // Do any additional setup after loading the view, typically from a nib.
    self.testDic = @{@"key1":@"value1",@"key2":@2,@"key3":@"3",@"key4":@"k4"};
//    testObj->inspectView = self.inspectView;
//    testObj->testInt = 5;
    self.inspectView.inspectingObject = testObj;
    
    AppDelegate *app = [UIApplication sharedApplication].delegate;
    id var = [app valueForKeyPath:@"testVar"];
    
}



@end
