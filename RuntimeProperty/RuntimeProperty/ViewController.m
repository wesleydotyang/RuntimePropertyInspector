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
#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>

@interface TestObject : NSObject
{
//    @public
    FFPropertyInspectView *inspectView;
    int _testInt;
    CGRect _testRect;
    CGPoint _testPoint;
    long long longValue;
}
//@property (weak, nonatomic)  FFPropertyInspectView *inspectView;
@property (nonatomic) UIImage *image;
@property (nonatomic) CGRect rect;
@property (nonatomic) CGSize size;
@property (nonatomic) CATransform3D transform;
@property (nonatomic) NSArray *testArray;
@property (nonatomic,strong) NSDictionary *testDic;

@property (nonatomic) NSString *testStr;
@property (nonatomic) JSContext *vm;
@end

@implementation TestObject


@end



@interface ViewController (){
}
@property (weak, nonatomic) IBOutlet FFPropertyInspectView *inspectView;

@property (nonatomic) CGRect rect;

@end

@implementation ViewController



- (void)viewDidLoad {
    [super viewDidLoad];
//    [self.class test];

    TestObject *testObj = [TestObject new];
//    testObj->testRect = CGRectMake(1, 1, 2, 3);
    testObj.rect = CGRectMake(0, 1, 2, 3);
    testObj.testArray = [NSMutableArray arrayWithArray:@[@4,@1,@2]];
    // Do any additional setup after loading the view, typically from a nib.
    testObj.testDic = [NSMutableDictionary dictionaryWithDictionary: @{@"key1":@YES,@"key2":@2,@"key3":@"3",@"key4":@"k4"}];
//    testObj->inspectView = self.inspectView;
//    testObj->testInt = 5;
    testObj.vm = [[JSContext alloc] init];
    testObj.image = [UIImage imageNamed:@"test"];
    self.inspectView.inspectingObject = testObj;
    
    AppDelegate *app = [UIApplication sharedApplication].delegate;
    id var = [app valueForKeyPath:@"testVar"];
    
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        id obj = self.inspectView.inspectingObject;
        NSLog(@"");
    }];
    
}



@end
