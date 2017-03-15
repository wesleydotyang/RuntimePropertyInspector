//
//  FFPropertyInspectViewController.m
//  RuntimeProperty
//
//  Created by Wesley Yang on 2017/3/15.
//  Copyright © 2017年 ff. All rights reserved.
//

#import "FFPropertyInspector.h"

#ifdef FFPropertyInspectorOn

#import "FFPropertyInspectViewController.h"
#import "FFPropertyInspectView.h"

@interface FFPropertyInspectViewController ()

@end

@implementation FFPropertyInspectViewController

-(void)loadView
{
    self.view = [[FFPropertyInspectView alloc] init];
}


@end

#endif
