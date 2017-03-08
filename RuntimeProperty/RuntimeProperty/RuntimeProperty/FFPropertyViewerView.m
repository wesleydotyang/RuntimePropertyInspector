//
//  FFPropertyViewerView.m
//  RuntimeProperty
//
//  Created by Wesley Yang on 2017/3/8.
//  Copyright © 2017年 ff. All rights reserved.
//

#import "FFPropertyViewerView.h"

@interface FFPropertyViewerView()
@property (nonatomic) UIView *contentView;
@end

@implementation FFPropertyViewerView

-(instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor darkGrayColor];
        self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 30, frame.size.width, frame.size.height - 30)];
        self.contentView.clipsToBounds = YES;
        [self addSubview:self.contentView];
        
        UIButton *closeButton = [[UIButton alloc] initWithFrame:CGRectMake(10, 0, 50, 30)];
        [closeButton setTitle:@"[Close]" forState:UIControlStateNormal];
        closeButton.titleLabel.font = [UIFont systemFontOfSize:15];
        [closeButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [closeButton addTarget:self action:@selector(doCloseTapped) forControlEvents:UIControlEventTouchUpInside];
        closeButton.tag = 1;
        [self addSubview:closeButton];
    }
    return self;
}

-(void)doCloseTapped
{
    [self removeFromSuperview];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
}

-(void)setTargetObject:(id)targetObject
{
    _targetObject = targetObject;
    
    if ([targetObject isKindOfClass:[UIImage class]]) {
        [self displayImage:targetObject];
    }else{
        [self displayText:[NSString stringWithFormat:@"%@",targetObject]];
    }
}

-(void)displayText:(NSString*)text
{
    UITextView *textView = [[UITextView alloc] init];
    textView.text = text;
    textView.frame = self.contentView.bounds;
    [self.contentView addSubview:textView];
}

-(void)displayImage:(UIImage*)image
{
    UIImageView *imgView = [[UIImageView alloc] init];
    imgView.contentMode = UIViewContentModeCenter;
    imgView.image = image;
    imgView.frame = self.contentView.bounds;
    [self.contentView addSubview:imgView];
}

@end
