//
//  XYPieChartForDictView.m
//  XYPieChart
//
//  Created by Tod Cunningham on 6/7/14.
//  Copyright (c) 2014 Xiaoyang Feng. All rights reserved.
//
#import "XYPieChartForDictView.h"



@implementation XYPieChartForDictView







- (void)setDataSourceDict:(NSDictionary *)dataSourceDict keyOrder:(NSArray *)keyOrder
{
    assert( [[NSSet setWithArray:dataSourceDict.allKeys] isEqualToSet:[NSSet setWithArray:keyOrder]] );
    
    if( self.dataSource == nil )
        self.dataSource = self;
    
    // When using a data source dictionary we need to be the dataSource delegate.
    assert( self.dataSource == self );

    m_dataSourceOrderedKeys = keyOrder;
    m_dataSourceDict        = [dataSourceDict copy];
    [self reloadData];
}




- (void)setDataSourceDict:(NSDictionary *)dataSourceDict
{
    [self setDataSourceDict:dataSourceDict keyOrder:[dataSourceDict keysSortedByValueUsingSelector:@selector(compare:)]];
}




- (NSUInteger)numberOfSlicesInPieChart:(XYPieChart *)pieChart
{
    return m_dataSourceOrderedKeys.count;
}



- (CGFloat)pieChart:(XYPieChart *)pieChart valueForSliceAtIndex:(NSUInteger)index
{
    NSString *key = [m_dataSourceOrderedKeys objectAtIndex:index];
    assert( key );
    NSNumber *value = [m_dataSourceDict objectForKey:key];
    assert( [value isKindOfClass:NSNumber.class] );
    
    return value.floatValue;
}



- (UIColor *)pieChart:(XYPieChart *)pieChart colorForSliceAtIndex:(NSUInteger)index
{
    UIColor *color = nil;
    
    if( index < m_dataSourceOrderedKeys.count )
    {
        NSString *key = [m_dataSourceOrderedKeys objectAtIndex:index];
        color = [_colorDict objectForKey:key];
        if( color != nil )
            assert( [color isKindOfClass:UIColor.class] );
    }
    
    return color;
}




- (NSString *)pieChart:(XYPieChart *)pieChart textForSliceAtIndex:(NSUInteger)index
{
    if( !_showDictLabel )
        return nil;
    
    NSString *key = [m_dataSourceOrderedKeys objectAtIndex:index];
    
    NSLog( @"pieChart text for slice %d:%@", index, key );
    
    return key;
}




- (UIView *)makeLabelKeyViewAtPoint:(CGPoint)point
{
    CGSize maxLabelSize  = CGSizeMake(0, 0);
    
    // Find the largest label size
    for( NSString *key in m_dataSourceOrderedKeys )
    {
        CGSize textSize = [key sizeWithAttributes:@{NSFontAttributeName:self.labelFont}];
        
        if( maxLabelSize.width < textSize.width )
            maxLabelSize.width = textSize.width;
        
        if( maxLabelSize.height < textSize.height )
            maxLabelSize.height = textSize.height;
    }

    float    xMargin  = 8;
    float    yMargin  = 8;
    CGSize   viewSize = CGSizeMake(m_dataSourceOrderedKeys.count * (maxLabelSize.width + xMargin), m_dataSourceOrderedKeys.count * (maxLabelSize.height + yMargin) );
    UIView  *view     = [[UIView alloc] initWithFrame:CGRectMake(point.x, point.y, viewSize.width, viewSize.height)];

    for( int index = 0;  index < m_dataSourceOrderedKeys.count;  index += 1 )
    {
        UILabel  *label = [[UILabel alloc] initWithFrame:CGRectMake(0, index * (maxLabelSize.height + yMargin), maxLabelSize.width, maxLabelSize.height)];
        NSString *key   = [m_dataSourceOrderedKeys objectAtIndex:index];
        
        label.text = key;
        label.font = self.labelFont;
        label.textColor = self.labelColor;
        
        [view addSubview:label];
    }
    
    return view;
}


@end
