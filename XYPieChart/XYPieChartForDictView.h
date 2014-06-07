//
//  XYPieChartForDictView.h
//  XYPieChart
//
//  Created by Tod Cunningham on 6/7/14.
//  Copyright (c) 2014 Xiaoyang Feng. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "XYPieChart.h"


@interface XYPieChartForDictView : XYPieChart <XYPieChartDataSource>
{
    NSArray      *m_dataSourceOrderedKeys;
    NSDictionary *m_dataSourceDict;
}

@property (nonatomic) NSDictionary *colorDict;
@property (nonatomic) bool showDictLabel;

- (void)setDataSourceDict:(NSDictionary *)dataSourceDict keyOrder:(NSArray *)keyOrder;
- (void)setDataSourceDict:(NSDictionary *)dataSourceDict;

- (UIView *)makeLabelKeyViewAtPoint:(CGPoint)point;

@end
