//
//  FFPropertyViewerView.h
//  RuntimeProperty
//
//  Created by Wesley Yang on 2017/3/8.
//  Copyright © 2017年 ff. All rights reserved.
//

#import "FFPropertyInspector.h"

#ifdef FFPropertyInspectorOn

#import "FFInstanceNode.h"
#import <UIKit/UIKit.h>

@interface FFPropertyViewerView : UIView

@property (nonatomic) id targetObject;

@end


#endif
