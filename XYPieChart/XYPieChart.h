//
//  XYPieChart.h
//  XYPieChart
//
//  Created by XY Feng on 2/24/12.
//  Copyright (c) 2012 Xiaoyang Feng. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.

#import <UIKit/UIKit.h>

/**    ___
        /3|4\
 |-+-|
 \2|1/
 */
typedef enum {
    XYPieChartQuadrantUnknown   = 0,                //0000
    XYPieChartFirstQuadrant     = (0x1 << 0),       //0001
    XYPieChartSecondQuadrant    = (0x1 << 1),       //0010
    XYPieChartThirdQuadrant     = (0x1 << 2),       //0100
    XYPieChartFourthQuadrant    = (0x1 << 3),       //1000
    XYPieChartBottomQuadrant    = (0x3 << 0),       //0011
    XYPieChartTopQuadrant       = (0x3 << 2),       //1100
    XYPieChartLeftQuadrant      = (0x6 << 0),       //0110
    XYPieChartRightQuadrant     = (0x9 << 0),       //1001
} XYPieChartQuadrant;

@class XYPieChart;
@protocol XYPieChartDataSource <NSObject>
@required
- (NSUInteger)numberOfSlicesInPieChart:(XYPieChart*)pieChart;
- (CGFloat)pieChart:(XYPieChart*)pieChart valueForSliceAtIndex:(NSUInteger)index;
@optional
- (UIColor*)pieChart:(XYPieChart*)pieChart colorForSliceAtIndex:(NSUInteger)index;
- (NSString*)pieChart:(XYPieChart*)pieChart textForSliceAtIndex:(NSUInteger)index;
- (UIView*)pieChart:(XYPieChart*)pieChart detailViewForSliceAtIndex:(NSUInteger)index andQuadrant:(XYPieChartQuadrant)quadrant;
@end

@protocol XYPieChartDelegate <NSObject>
@optional
- (void)pieChart:(XYPieChart*)pieChart willSelectSliceAtIndex:(NSUInteger)index;
- (void)pieChart:(XYPieChart*)pieChart didSelectSliceAtIndex:(NSUInteger)index;
- (void)pieChart:(XYPieChart*)pieChart willDeselectSliceAtIndex:(NSUInteger)index;
- (void)pieChart:(XYPieChart*)pieChart didDeselectSliceAtIndex:(NSUInteger)index;
@end

@interface XYPieChart : UIView
@property(nonatomic, weak) id<XYPieChartDataSource> dataSource;
@property(nonatomic, weak) id<XYPieChartDelegate> delegate;
@property(nonatomic, assign) CGFloat startPieAngle;
@property(nonatomic, assign) CGFloat animationSpeed;
@property(nonatomic, assign) CGPoint pieCenter;
@property(nonatomic, assign) CGFloat pieInnerRadius;
@property(nonatomic, assign) CGFloat pieOuterRadius;
@property(nonatomic, assign) BOOL    showLabel;
@property(nonatomic, strong) UIFont  *labelFont;
@property(nonatomic, strong) UIColor *labelColor;
@property(nonatomic, strong) UIColor *labelSelectedColor;
@property(nonatomic, strong) UIColor *labelShadowColor;
@property(nonatomic, assign) CGFloat labelRadius;
@property(nonatomic, assign) CGFloat selectedSliceStroke;
@property(nonatomic, assign) CGFloat selectedSliceOffsetRadius;
@property(nonatomic, strong) UIColor *selectedSliceColor;
@property(nonatomic, assign) BOOL    showPercentage;
@property(nonatomic, assign) BOOL    shouldRotateWhenSliceSelected;

- (id)initWithFrame:(CGRect)frame Center:(CGPoint)center Radius:(CGFloat)radius;
- (void)reloadData;
- (void)setPieBackgroundColor:(UIColor*)color;

- (void)setSliceSelectedAtIndex:(NSInteger)index;
- (void)setSliceDeselectedAtIndex:(NSInteger)index;

@end