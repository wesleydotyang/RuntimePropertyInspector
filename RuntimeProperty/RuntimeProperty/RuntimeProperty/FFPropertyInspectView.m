//
//  FFPropertyInspectView.m
//  RuntimeProperty
//
//  Created by Wesley Yang on 16/5/10.
//  Copyright © 2016年 ff. All rights reserved.
//

#import "FFPropertyInspectView.h"
#import "FFPropertyInspector.h"

#define INDENT_DISTANCE_PER_LEVEL  20

typedef void(^InputValueCallback)(id value);


@interface FFPropertyCell : UITableViewCell
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *detailLabel;
@property (nonatomic) FFInstanceNode *nodeData;
+(CGFloat)heightForNode:(FFInstanceNode*)node totalWid:(CGFloat)totalWid;
@end

@interface FFPropertyInspectView()<UITableViewDelegate,UITableViewDataSource,UIAlertViewDelegate>

@property (nonatomic) UITableView *tableView;

@property (nonatomic,strong) FFInstanceNode *rootNode;

@property (nonatomic,strong) NSArray<FFInstanceNode*> *tableDisplayNodes;

@property (nonatomic,copy) InputValueCallback inputValueCallback;
@end

@implementation FFPropertyInspectView


-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self setupThis];
    }
    return self;
}

-(instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setupThis];
    }
    return self;
}

-(void)setupThis
{
    [self addSubview:self.tableView];
}

-(void)setInspectingObject:(id)inspectingObject
{
    _inspectingObject = inspectingObject;
    
    self.rootNode = [FFPropertyInspector nodeDataForInstance:_inspectingObject];
    [self reloadTableData];
    
}

-(BOOL)isNodeExpanded:(FFInstanceNode*)node
{
    return [node.userInfo[@"expanded"] boolValue];
}

-(void)setNode:(FFInstanceNode*)node expanded:(BOOL)expanded
{
    node.userInfo[@"expanded"] = @(expanded);
}

-(void)reloadTableData
{
    NSMutableArray *tableData = [NSMutableArray array];
    [self appendTableData:tableData forNode:self.rootNode];
    self.tableDisplayNodes = tableData;
    [self.tableView reloadData];
}

-(void)appendTableData:(NSMutableArray*)tableData forNode:(FFInstanceNode*)node
{
    [tableData addObject:node];
    if ([self isNodeExpanded:node]) {
        if (node.superClassNode) {
            [self appendTableData:tableData forNode:node.superClassNode];
        }
        for (FFInstanceNode *subNode in node.properties) {
            [self appendTableData:tableData forNode:subNode];
        }
        for (FFInstanceNode *ivarNode in node.ivars) {
            [self appendTableData:tableData forNode:ivarNode];
        }
    }
    
}


-(void)layoutSubviews
{
    [super layoutSubviews];
    self.tableView.frame = self.bounds;
}

-(UITableView *)tableView
{
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStyleGrouped];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        [_tableView registerClass:[FFPropertyCell class] forCellReuseIdentifier:@"cell"];
    }
    return _tableView;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [FFPropertyCell heightForNode:self.tableDisplayNodes[indexPath.row] totalWid:self.frame.size.width];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.tableDisplayNodes.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FFPropertyCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    FFInstanceNode *node = self.tableDisplayNodes[indexPath.row];

    cell.separatorInset = UIEdgeInsetsMake(0, INDENT_DISTANCE_PER_LEVEL*node.depth, 0, 0);
    cell.nodeData = node;
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *eidtableTypes = @[@"BOOL",@"int",@"float",@"double",@"long",@"long long",@"unsigned long",@"unsigned long long",@"NSString",@"CGRect",@"CGSize",@"CGPoint"];
    FFInstanceNode *node = self.tableDisplayNodes[indexPath.row];
    if ([self isNodeExpanded:node] == NO) {
        if ([eidtableTypes containsObject:node.instanceType]) {
            [self modifyNode:node];
        }else{
            [FFPropertyInspector expandInstanceNode:node];
            [self setNode:node expanded:YES];
            [self reloadTableData];
        }
        
    }else{
        [self setNode:node expanded:NO];
        [self reloadTableData];
    }
}

-(void)modifyNode:(FFInstanceNode*)node
{

    if (    [node.instanceType isEqualToString: @"BOOL"]
         || [node.instanceType isEqualToString: @"int"]
         || [node.instanceType isEqualToString:@"float"]
         || [node.instanceType isEqualToString:@"double"]
         || [node.instanceType isEqualToString:@"long"]
         || [node.instanceType isEqualToString:@"long long"]
         || [node.instanceType isEqualToString:@"unsigned long"]
         || [node.instanceType isEqualToString:@"unsigned long long" ]
         ) {
        __weak FFPropertyInspectView *weakSelf = self;
        [self setInputValueCallback:^(id value){
            NSString *strValue = value;
            NSNumber *numValue = @0;
            if (strValue) {
                NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
                f.numberStyle = NSNumberFormatterDecimalStyle;
                numValue = [f numberFromString:strValue];
            }
            if (numValue) {
                [FFPropertyInspector alterInstance:node toValue:numValue];
                [weakSelf reloadTableData];
            }else{
                [FFPropertyInspectView alertMsg:@"not a valid input"];
            }
        }];
        NSNumber *numValue = node.rawValue;
        [self inputTextValueWithDefault:numValue.stringValue];
        
    }else if([node.instanceType isEqualToString:@"NSString"]){
        __weak FFPropertyInspectView *weakSelf = self;
        [self setInputValueCallback:^(id value){
            NSString *strValue = value;
            [FFPropertyInspector alterInstance:node toValue:strValue];
            [weakSelf reloadTableData];
        }];
        [self inputTextValueWithDefault:node.rawValue];
        
    }else if([node.instanceType isEqualToString:@"CGRect"]){
        __weak FFPropertyInspectView *weakSelf = self;
        [self setInputValueCallback:^(id value){
            NSString *strValue = value;
            CGRect rectValue = CGRectFromString(strValue);
            [FFPropertyInspector alterInstance:node toValue:[NSValue valueWithCGRect:rectValue]];
            [weakSelf reloadTableData];
        }];
        CGRect rectValue = [node.rawValue CGRectValue];
        [self inputTextValueWithDefault:NSStringFromCGRect(rectValue)];
        
    }else if([node.instanceType isEqualToString:@"CGSize"]){
        __weak FFPropertyInspectView *weakSelf = self;
        [self setInputValueCallback:^(id value){
            NSString *strValue = value;
            CGSize newValue = CGSizeFromString(strValue);
            [FFPropertyInspector alterInstance:node toValue:[NSValue valueWithCGSize:newValue]];
            [weakSelf reloadTableData];
        }];
        CGSize originValue = [node.rawValue CGSizeValue];
        [self inputTextValueWithDefault:NSStringFromCGSize(originValue)];
        
    }else if([node.instanceType isEqualToString:@"CGPoint"]){
        __weak FFPropertyInspectView *weakSelf = self;
        [self setInputValueCallback:^(id value){
            NSString *strValue = value;
            CGPoint newValue = CGPointFromString(strValue);
            [FFPropertyInspector alterInstance:node toValue:[NSValue valueWithCGPoint:newValue]];
            [weakSelf reloadTableData];
        }];
        CGPoint originValue = [node.rawValue CGPointValue];
        [self inputTextValueWithDefault:NSStringFromCGPoint(originValue)];
        
    }
}


+(void)alertMsg:(NSString*)msg
{
    [[[UIAlertView alloc] initWithTitle:nil message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
}

-(void)inputTextValueWithDefault:(NSString*)defaultValue
{
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Input new value" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    if (defaultValue) {
        [alert textFieldAtIndex:0].text = defaultValue;
    }
    [alert show];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == alertView.firstOtherButtonIndex) {
        UITextField *tf = [alertView textFieldAtIndex:0];
        self.inputValueCallback(tf.text);
    }
}

@end



@implementation FFPropertyCell


-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.nameLabel = [[UILabel alloc] init];
        self.nameLabel.textColor = [UIColor blackColor];
        self.nameLabel.font = [UIFont systemFontOfSize:11];
        [self.contentView addSubview:self.nameLabel];
        
        self.detailLabel = [[UILabel alloc] init];
        self.detailLabel.textColor = [UIColor darkGrayColor];
        self.detailLabel.textAlignment = NSTextAlignmentRight;
        self.detailLabel.font = [UIFont systemFontOfSize:9];
        self.detailLabel.numberOfLines = 0;
        [self.contentView addSubview:self.detailLabel];
    }
    return self;
}

-(void)setNodeData:(FFInstanceNode *)nodeData
{
    _nodeData = nodeData;

    self.nameLabel.text = [self.class titleDescriptionForNode:nodeData];
    self.detailLabel.attributedText = [self.class detailDescriptionForNode:nodeData];
    
    [self setNeedsLayout];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    self.nameLabel.frame = CGRectMake(10+INDENT_DISTANCE_PER_LEVEL*self.nodeData.depth, 0, self.frame.size.width-INDENT_DISTANCE_PER_LEVEL*self.nodeData.depth, 25);
    float titleWid = [[self.class titleDescriptionForNode:self.nodeData] sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:11]}].width;
    float detailLeft = titleWid + self.nameLabel.frame.origin.x + 10;

    self.detailLabel.frame = CGRectMake(detailLeft,0, self.frame.size.width-detailLeft-10, self.frame.size.height);
    
}

+(NSString*)titleDescriptionForNode:(FFInstanceNode*)node
{
    if ([node isKindOfClass:[FFPropertyNode class]]) {
        return [@"- " stringByAppendingString:node.instanceName];
    }else if([node isKindOfClass:[FFIVarNode class]]){
        return [@"> " stringByAppendingString:node.instanceName];
    }else if(node.inheritClassNode){
        return [NSString stringWithFormat:@"super %@",node.instanceName];
    }
    return node.instanceName;
}

+(NSAttributedString*)detailDescriptionForNode:(FFInstanceNode*)node
{
    NSMutableAttributedString *attString = [[NSMutableAttributedString alloc] init];
    NSAttributedString *typeAtt = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"(%@)",node.instanceType] attributes:@{NSForegroundColorAttributeName:[UIColor lightGrayColor]}];
    NSString *valueStr;
    if (node.rawValueValid && !node.inheritClassNode) {
        valueStr = [NSString stringWithFormat:@"%@",node.rawValue];
    }else{
        valueStr = @"_";
    }
    NSAttributedString *valueAtt = [[NSAttributedString alloc] initWithString:valueStr];
    [attString appendAttributedString:typeAtt];
    [attString appendAttributedString:valueAtt];
    return attString;
}


+(CGFloat)heightForNode:(FFInstanceNode*)node totalWid:(CGFloat)totalWid
{
    NSString *title = [self titleDescriptionForNode:node];
    NSString *detail = [self detailDescriptionForNode:node].string;
    float titleWid = [title sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:11]}].width;
    float detailWid = totalWid - titleWid - 30 - INDENT_DISTANCE_PER_LEVEL*node.depth;
    float detailHeight = [detail boundingRectWithSize:CGSizeMake(detailWid, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:9]} context:nil].size.height;
    return MAX(25, detailHeight + 15);
}

@end
