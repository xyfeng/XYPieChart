//
//  XYPieView.h
//  XYPieChart
//
//  Created by XY Feng on 2/24/12.
//  Copyright (c) 2012 Xiaoyang Feng. All rights reserved.
//

#import <UIKit/UIKit.h>

@class XYPieChart;
@protocol XYPieViewDataSource <NSObject>
@required
- (NSUInteger)numberOfSlicesInPieView:(XYPieChart *)pieView;
- (CGFloat)pieView:(XYPieChart *)pieView valueForSliceAtIndex:(NSUInteger)index;
@optional
- (UIColor *)pieView:(XYPieChart *)pieView colorForSliceAtIndex:(NSUInteger)index;
@end

@protocol XYPieViewDelegate <NSObject>
@optional
- (void)pieView:(XYPieChart *)pieView willSelectSliceAtIndex:(NSUInteger)index;
- (void)pieView:(XYPieChart *)pieView didSelectSliceAtIndex:(NSUInteger)index;
- (void)pieView:(XYPieChart *)pieView willDeselectSliceAtIndex:(NSUInteger)index;
- (void)pieView:(XYPieChart *)pieView didDeselectSliceAtIndex:(NSUInteger)index;
@end

@interface XYPieChart : UIView
@property(nonatomic, weak) id<XYPieViewDataSource> dataSource;
@property(nonatomic, weak) id<XYPieViewDelegate> delegate;
@property(nonatomic, assign) CGFloat startPieAngle;
@property(nonatomic, assign) CGFloat animationSpeed;
@property(nonatomic, assign) CGPoint pieCenter;
@property(nonatomic, assign) CGFloat pieRadius;
@property(nonatomic, assign) BOOL    showLabel;
@property(nonatomic, strong) UIFont  *labelFont;
@property(nonatomic, assign) CGFloat labelRadius;
@property(nonatomic, assign) CGFloat selectionStroke;
@property(nonatomic, assign) BOOL    showPercentage;
- (id)initWithFrame:(CGRect)frame Center:(CGPoint)center Radius:(CGFloat)radius;
- (void)reloadData;
@end;
