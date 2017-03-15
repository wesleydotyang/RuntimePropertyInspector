//
//  FFPropertyInspectView.m
//  RuntimeProperty
//
//  Created by Wesley Yang on 16/5/10.
//  Copyright © 2016年 ff. All rights reserved.
//
#import "FFPropertyInspector.h"

#ifdef FFPropertyInspectorOn

#import "FFPropertyInspectView.h"
#import "FFPropertyViewerView.h"

#define INDENT_DISTANCE_PER_LEVEL  20

typedef void(^FFInputValueCallback)(id value);
@class FFPropertyCell;

@protocol FFPopertyCellDelegate <NSObject>

-(void)propertyCellDidTapDetailButton:(FFPropertyCell*)cell;

@end

@interface FFPropertyCell : UITableViewCell
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *detailLabel;
@property (nonatomic) UIButton *infoButton;
@property (nonatomic) FFInstanceNode *nodeData;

@property (nonatomic,weak) id<FFPopertyCellDelegate> delegate;
+(CGFloat)heightForNode:(FFInstanceNode*)node totalWid:(CGFloat)totalWid;
@end

@interface FFTableView : UITableView
@end

@interface FFPropertyInspectView()<UITableViewDelegate,UITableViewDataSource,UIAlertViewDelegate,FFPopertyCellDelegate,UISearchResultsUpdating>

@property (nonatomic) UITableView *tableView;
@property (nonatomic) UISearchController *searchController;

@property (nonatomic,strong) NSArray<FFInstanceNode*> *rootNodes;

@property (nonatomic,strong) NSArray<FFInstanceNode*> *tableDisplayNodes;

@property (nonatomic,copy) FFInputValueCallback inputValueCallback;
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
    [self setupSearchController];
}

-(void)setupSearchController
{
    self.searchController = [[UISearchController alloc]initWithSearchResultsController:nil];
    self.searchController.searchBar.frame = CGRectMake(0, 0, 0, 44);
    self.searchController.dimsBackgroundDuringPresentation = false;
    //搜索栏表头视图
    self.tableView.tableHeaderView = self.searchController.searchBar;
    [self.searchController.searchBar sizeToFit];

    self.searchController.searchResultsUpdater = self;
}

-(void)setInspectingObject:(id)inspectingObject
{
    _inspectingObject = inspectingObject;
    
    self.rootNodes = [NSMutableArray array];
    [(NSMutableArray*)self.rootNodes addObject:[FFPropertyInspector nodeDataForInstance:_inspectingObject]];
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
    for (FFInstanceNode *node in self.rootNodes) {
        [self appendTableData:tableData forNode:node];
    }
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
        for (FFElementNode *eleNode in node.elements) {
            [self appendTableData:tableData forNode:eleNode];
        }
        for (FFMethodNode * mNode in node.classMethods) {
            [self appendTableData:tableData forNode:mNode];
        }
        for (FFMethodNode * mNode in node.instanceMethods) {
            [self appendTableData:tableData forNode:mNode];
        }
    }
    
}


-(void)layoutSubviews
{
    [super layoutSubviews];
    self.tableView.frame = self.bounds;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(myUpdateSearchResults) object:nil];
    [self performSelector:@selector(myUpdateSearchResults) withObject:nil afterDelay:1];
}

-(void)myUpdateSearchResults
{
    NSString *query = self.searchController.searchBar.text;
    if (query.length != 0) {
        NSArray *result = [FFPropertyInspector searchForInstancesOfClassMatch:query];
        
        NSMutableDictionary<NSString*,FFInstanceNode*> *classDic = [NSMutableDictionary dictionary];
        for (NSValue *value in result) {
            NSString *className = NSStringFromClass([value class]);
            if (!classDic[className]) {
                FFInstanceNode *node = [[FFInstanceNode alloc] init];
                node.instanceName = className;
                node.instanceType = className;
                node.elements = [NSMutableArray array];
                classDic[className] = node;
            }
            FFInstanceNode *cnode = [FFPropertyInspector nodeDataForInstance:value];
            cnode.depth = 1;
            [(NSMutableArray*)classDic[className].elements addObject:cnode];
        }
        
        self.rootNodes = classDic.allValues;
 
    }
    
    [self reloadTableData];
}

-(UITableView *)tableView
{
    if (!_tableView) {
        _tableView = [[FFTableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
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
    cell.delegate = self;
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *eidtableTypes = @[@"BOOL",@"int",@"float",@"double",@"long",@"long long",@"unsigned long",@"unsigned long long",@"NSString",@"CGRect",@"CGSize",@"CGPoint",@"NSNumber"];
    FFInstanceNode *node = self.tableDisplayNodes[indexPath.row];
    if ([self isNodeExpanded:node] == NO) {
        if ([eidtableTypes containsObject:node.instanceType]) {
            [self modifyNode:node];
        }else if([node isKindOfClass:[FFMethodNode class]]){
            [self callMethodOnNode:(FFMethodNode*)node];
        
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

-(void)propertyCellDidTapDetailButton:(FFPropertyCell *)cell
{
    //view property detail
    FFPropertyViewerView *viewer = [[FFPropertyViewerView alloc] initWithFrame:CGRectMake(0, 44, self.frame.size.width, self.frame.size.height-44)];
    viewer.targetObject = cell.nodeData.rawValue;
    [self addSubview:viewer];
}

-(void)callMethodOnNode:(FFMethodNode*)node
{
    SEL selector = NSSelectorFromString(node.methodName);
    NSObject *target = node.parentNode.rawValue;
    if (selector && target){
        NSMethodSignature *signature = [target methodSignatureForSelector:selector];
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:target];
        [invocation setSelector:selector];
        NSUInteger argC = signature.numberOfArguments;
        if (argC == 2) {
            [invocation invoke];
        }
       
//        [invocation setArgument:&params atIndex:2];
//        [invocation setArgument:&data atIndex:3];

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
         || [node.instanceType isEqualToString:@"NSNumber"]
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
                if([FFPropertyInspector alterInstance:node toValue:numValue]){
                    [weakSelf reloadTableData];
                }else{
                    [FFPropertyInspectView alertMsg:@"modify value failed"];
                }
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
        
        self.infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
        [self.infoButton addTarget:self action:@selector(didTapInfoButton) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:self.infoButton];
    }
    return self;
}

-(void)didTapInfoButton
{
    if (self.delegate) {
        [self.delegate propertyCellDidTapDetailButton:self];
    }
}

-(void)setNodeData:(FFInstanceNode *)nodeData
{
    _nodeData = nodeData;

    self.nameLabel.text = [self.class titleDescriptionForNode:nodeData];
    self.detailLabel.attributedText = [self.class detailDescriptionForNode:nodeData limitDetail:YES];
    
    [self setNeedsLayout];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    float titleWid = [self.nameLabel.text sizeWithAttributes:@{NSFontAttributeName:self.nameLabel.font}].width;
    titleWid = MIN(self.frame.size.width/2,titleWid);
    self.nameLabel.frame = CGRectMake(10+INDENT_DISTANCE_PER_LEVEL*self.nodeData.depth, 0, titleWid, self.frame.size.height);
    self.infoButton.frame = CGRectMake(self.frame.size.width - 35, 0, 35, self.frame.size.height);

    self.detailLabel.frame = CGRectMake(CGRectGetMinX(self.nameLabel.frame)+titleWid+10,0, self.frame.size.width - CGRectGetMinX(self.nameLabel.frame)-titleWid - 10- CGRectGetWidth(self.infoButton.frame), self.frame.size.height);
    
}

+(NSString*)titleDescriptionForNode:(FFInstanceNode*)node
{
    if ([node isKindOfClass:[FFMethodNode class]]) {
        FFMethodNode *mNode = (FFMethodNode*)node;
        if (mNode.isClassMethod) {
            return [NSString stringWithFormat:@"+%@",mNode.methodName];
        }else{
            return [NSString stringWithFormat:@"-%@",mNode.methodName];
        }
    }
    
    if ([node isKindOfClass:[FFPropertyNode class]]) {
        return [@"@ " stringByAppendingString:node.instanceName];
    }else if([node isKindOfClass:[FFIVarNode class]]){
        return [@"> " stringByAppendingString:node.instanceName];
    }else if(node.inheritClassNode){
        return [NSString stringWithFormat:@"super %@",node.instanceName];
    }
    return node.instanceName;
}

+(NSAttributedString*)detailDescriptionForNode:(FFInstanceNode*)node limitDetail:(BOOL)limitDetail
{
    if ([node isKindOfClass:[FFMethodNode class]]) {
        return nil;
    }
    
    NSMutableAttributedString *attString = [[NSMutableAttributedString alloc] init];
    NSAttributedString *typeAtt = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"(%@)",node.instanceType] attributes:@{NSForegroundColorAttributeName:[UIColor lightGrayColor]}];
    NSString *valueStr;
    
    if (node.rawValueValid && !node.inheritClassNode) {
        if (node.safeToUseRawValue) {
            valueStr = [NSString stringWithFormat:@"%@",node.rawValue];
        }else{
            valueStr = [NSString stringWithFormat:@"%p",node.rawValue];
        }
        
        if (limitDetail) {
            if (valueStr.length > 40) {
                valueStr = [[valueStr substringToIndex:40] stringByAppendingString:@"..."];
            }
        }
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
    NSString *detail = [self detailDescriptionForNode:node limitDetail:YES].string;
    float titleWid = MIN(totalWid/2,[title sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:11]}].width);
    float detailWid = totalWid - titleWid - 65 - INDENT_DISTANCE_PER_LEVEL*node.depth;
    float detailHeight = [detail boundingRectWithSize:CGSizeMake(detailWid, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:9]} context:nil].size.height;
    return MAX(33, detailHeight + 15);
}

@end



@implementation FFTableView

@end

#endif
