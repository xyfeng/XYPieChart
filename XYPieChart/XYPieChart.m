//
//  XYPieChart.m
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

#import "XYPieChart.h"
#import <QuartzCore/QuartzCore.h>

@interface SliceLayer : CAShapeLayer

@property (nonatomic, assign) CGFloat   value;
@property (nonatomic, assign) CGFloat   percentage;
@property (nonatomic, assign) double    startAngle;
@property (nonatomic, assign) double    endAngle;
@property (nonatomic, assign) BOOL      isSelected;
@property (nonatomic, strong) NSString  *text;
@property (nonatomic, weak)   UIView    *detailView;

@end

@implementation SliceLayer

- (NSString*)description
{
    return [NSString stringWithFormat:@"value:%f, percentage:%0.0f, start:%f, end:%f", self.value, self.percentage, self.startAngle/M_PI*180, self.endAngle/M_PI*180];
}

+ (BOOL)needsDisplayForKey:(NSString*)key
{
    if ([key isEqualToString:@"startAngle"] || [key isEqualToString:@"endAngle"])
    {
        return YES;
    }
    else
    {
        return [super needsDisplayForKey:key];
    }
}

- (id)initWithLayer:(id)layer
{
    if (self = [super initWithLayer:layer])
    {
        if ([layer isKindOfClass:[SliceLayer class]])
        {
            self.startAngle = [(SliceLayer*)layer startAngle];
            self.endAngle = [(SliceLayer*)layer endAngle];
        }
    }
    return self;
}

- (void)createArcAnimationForKey:(NSString*)key fromValue:(NSNumber*)from toValue:(NSNumber*)to Delegate:(id)delegate
{
    CABasicAnimation *arcAnimation = [CABasicAnimation animationWithKeyPath:key];
    NSNumber *currentAngle = [[self presentationLayer] valueForKey:key];
    if(!currentAngle) currentAngle = from;
    [arcAnimation setFromValue:currentAngle];
    [arcAnimation setToValue:to];
    [arcAnimation setDelegate:delegate];
    [arcAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
    [self addAnimation:arcAnimation forKey:key];
    [self setValue:to forKey:key];
}
@end

@interface XYPieChart ()

@property (nonatomic, strong) UIView*           pieView;
@property (nonatomic, strong) UIImageView*      lightImageView;
@property (nonatomic, strong) UIImageView*      shadowImageView;
@property (nonatomic, strong) NSTimer*          animationTimer;
@property (nonatomic, strong) NSMutableArray*   animations;
@property (nonatomic, assign) CGFloat           currentPieOffsetAngle;
@property (nonatomic, readonly) NSInteger       selectedSliceIndex;

@end

@implementation XYPieChart

static NSUInteger kDefaultSliceZOrder = 100;

static CGPathRef CGPathCreateArc(CGPoint center, CGFloat innerRadius, CGFloat outerRadius, CGFloat startAngle, CGFloat endAngle)
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat xOffset = cos(startAngle)*outerRadius;
    CGFloat yOffset = sin(startAngle)*outerRadius;
    CGPathMoveToPoint(path, NULL, center.x + xOffset, center.y + yOffset);
    
    CGPathAddArc(path, NULL, center.x, center.y, outerRadius, startAngle, endAngle, 0);
    CGPathAddArc(path, NULL, center.x, center.y, innerRadius, endAngle, startAngle, 1);
    CGPathCloseSubpath(path);
    
    return path;
}

static XYPieChartQuadrant XYPieChartQuadrantForAngle(CGFloat angle)
{
    XYPieChartQuadrant quadrant = 0x0F;
    
    if (sin(angle) > 0)
    {
        quadrant &= XYPieChartBottomQuadrant;
    }
    else
    {
        quadrant &= XYPieChartTopQuadrant;
    }
    
    if (cos(angle) > 0)
    {
        quadrant &= XYPieChartRightQuadrant;
    }
    else
    {
        quadrant &= XYPieChartLeftQuadrant;
    }
    
    return quadrant;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        
        _pieView = [[UIView alloc] initWithFrame:frame];
        [self setupView];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame Center:(CGPoint)center Radius:(CGFloat)radius
{
    self = [self initWithFrame:frame];
    if (self)
    {
        self.pieCenter = center;
        self.pieOuterRadius = radius;
    }
    return self;
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self)
    {
        _pieView = [[UIView alloc] initWithFrame:self.bounds];
        [self setupView];
    }
    return self;
}

- (void)setupView
{
    self.backgroundColor = [UIColor clearColor];
    [_pieView setBackgroundColor:[UIColor clearColor]];
    [self insertSubview:_pieView atIndex:0];
    
    _animations = [[NSMutableArray alloc] init];
    
    _animationSpeed = 0.5;
    _startPieAngle = M_PI_2*3;
    _selectedSliceStroke = 3.0;
    
    CGRect bounds = [[self layer] bounds];
    self.pieOuterRadius = MIN(bounds.size.width/2, bounds.size.height/2) - 10;
    self.pieInnerRadius = 0.f;
    self.pieCenter = CGPointMake(bounds.size.width/2, bounds.size.height/2);
    self.labelFont = [UIFont boldSystemFontOfSize:MAX((int)self.pieOuterRadius/10, 5)];
    _labelColor = [UIColor whiteColor];
    _labelSelectedColor = [UIColor blackColor];
    _labelRadius = _pieOuterRadius/2;
    _selectedSliceOffsetRadius = MAX(10, _pieOuterRadius/10);
    _shouldRotateWhenSliceSelected = NO;
    
    _showLabel = YES;
    _showPercentage = YES;
    _currentPieOffsetAngle = 0.f;
    
}

#pragma mark Properties

- (void)setPieCenter:(CGPoint)pieCenter
{
    [self.pieView setCenter:pieCenter];
    _pieCenter = CGPointMake(_pieView.frame.size.width/2, _pieView.frame.size.height/2);
}

- (void)setPieOuterRadius:(CGFloat)pieOuterRadius
{
    _pieOuterRadius = pieOuterRadius;
    CGPoint origin = self.pieView.frame.origin;
    CGRect frame = CGRectMake(origin.x+self.pieCenter.x-pieOuterRadius, origin.y+self.pieCenter.y-pieOuterRadius, pieOuterRadius*2, pieOuterRadius*2);
    self.pieCenter = CGPointMake(frame.size.width/2, frame.size.height/2);
    [self.pieView setFrame:frame];
    [self.pieView.layer setCornerRadius:self.pieOuterRadius];
}

- (void)setPieInnerRadius:(CGFloat)pieInnerRadius
{
    if (pieInnerRadius < 0)
    {
        _pieInnerRadius = 0;
    }
    else if (pieInnerRadius >= self.pieOuterRadius)
    {
        _pieInnerRadius = self.pieOuterRadius-1;
    }
    else
    {
        _pieInnerRadius = pieInnerRadius ;
    }
}

- (void)setPieBackgroundColor:(UIColor*)color
{
    [self.pieView setBackgroundColor:color];
}

- (NSInteger)selectedSliceIndex
{
    __block NSInteger selectedIndex = -1;
    NSArray* layers = [self.pieView.layer.sublayers copy];
    [layers enumerateObjectsUsingBlock:^(CAShapeLayer* layer, NSUInteger idx, BOOL *stop)
    {
        if ([layer isKindOfClass:[SliceLayer class]])
        {
            SliceLayer* sliceLayer = (SliceLayer*)layer;
            if (sliceLayer.isSelected)
            {
                selectedIndex = idx;
                *stop = YES;
            }
        }
    }];
    return selectedIndex;
}

#pragma mark - manage settings

- (void)setShowPercentage:(BOOL)showPercentage
{
    _showPercentage = showPercentage;
    for(SliceLayer *layer in self.pieView.layer.sublayers)
    {
        CATextLayer *textLayer = [[layer sublayers] objectAtIndex:0];
        [textLayer setHidden:!self.showLabel];
        if(!self.showLabel) return;
        NSString *label;
        if(self.showPercentage)
            label = [NSString stringWithFormat:@"%0.0f", layer.percentage*100];
        else
            label = (layer.text)?layer.text:[NSString stringWithFormat:@"%0.0f", layer.value];
        CGSize size = [label sizeWithFont:self.labelFont];
        
        if(M_PI*2*self.labelRadius*layer.percentage < MAX(size.width,size.height))
        {
            [textLayer setString:@""];
        }
        else
        {
            [textLayer setString:label];
            [textLayer setBounds:CGRectMake(0, 0, size.width, size.height)];
        }
    }
}

#pragma mark - Pie Reload Data With Animation

- (void)reloadData
{
    if (self.dataSource)
    {
        CALayer *parentLayer = [self.pieView layer];
        NSArray *slicelayers = [parentLayer sublayers];
        
        [slicelayers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
        {
            SliceLayer *layer = (SliceLayer*)obj;
            if(layer.isSelected)
            {
                [self setSliceDeselectedAtIndex:idx];
            }
        }];
        [self setDetailViewsVisibles:NO];
        
        double startToAngle = self.startPieAngle + self.currentPieOffsetAngle;
        double endToAngle = self.startPieAngle + self.currentPieOffsetAngle;
        
        
        NSUInteger sliceCount = [self.dataSource numberOfSlicesInPieChart:self];
        
        double sum = 0.0;
        double values[sliceCount];
        for (int index = 0; index < sliceCount; index++)
        {
            values[index] = [self.dataSource pieChart:self valueForSliceAtIndex:index];
            sum += values[index];
        }
        
        double angles[sliceCount];
        for (int index = 0; index < sliceCount; index++)
        {
            double div;
            if (sum == 0)
                div = 0;
            else
                div = values[index] / sum;
            angles[index] = M_PI * 2 * div;
        }
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:self.animationSpeed];
        
        [self.pieView setUserInteractionEnabled:NO];
        
        __block NSMutableArray *layersToRemove = nil;
        
        BOOL isOnStart = ([slicelayers count] == 0 && sliceCount);
        NSInteger diff = sliceCount - [slicelayers count];
        layersToRemove = [NSMutableArray arrayWithArray:slicelayers];
        
        BOOL isOnEnd = ([slicelayers count] && (sliceCount == 0 || sum <= 0));
        if(isOnEnd)
        {
            for(SliceLayer *layer in self.pieView.layer.sublayers){
                [self updateLabelForLayer:layer value:0];
                [layer createArcAnimationForKey:@"startAngle"
                                      fromValue:[NSNumber numberWithDouble:self.startPieAngle]
                                        toValue:[NSNumber numberWithDouble:self.startPieAngle]
                                       Delegate:self];
                [layer createArcAnimationForKey:@"endAngle"
                                      fromValue:[NSNumber numberWithDouble:self.startPieAngle]
                                        toValue:[NSNumber numberWithDouble:self.startPieAngle]
                                       Delegate:self];
            }
            [CATransaction commit];
            return;
        }
        
        for(int index = 0; index < sliceCount; index ++)
        {
            SliceLayer *layer;
            double angle = angles[index];
            endToAngle += angle;
            double startFromAngle = self.startPieAngle + startToAngle;
            double endFromAngle = self.startPieAngle + endToAngle;
            
            if( index >= [slicelayers count] )
            {
                layer = [self createSliceLayer];
                if (isOnStart)
                    startFromAngle = endFromAngle = self.startPieAngle;
                [parentLayer addSublayer:layer];
                diff--;
            }
            else
            {
                SliceLayer *onelayer = [slicelayers objectAtIndex:index];
                if(diff == 0 || onelayer.value == (CGFloat)values[index])
                {
                    layer = onelayer;
                    [layersToRemove removeObject:layer];
                }
                else if(diff > 0)
                {
                    layer = [self createSliceLayer];
                    [parentLayer insertSublayer:layer atIndex:index];
                    diff--;
                }
                else if(diff < 0)
                {
                    while(diff < 0)
                    {
                        [onelayer removeFromSuperlayer];
                        [parentLayer addSublayer:onelayer];
                        diff++;
                        onelayer = [slicelayers objectAtIndex:index];
                        if(onelayer.value == (CGFloat)values[index] || diff == 0)
                        {
                            layer = onelayer;
                            [layersToRemove removeObject:layer];
                            break;
                        }
                    }
                }
            }
            
            layer.value = values[index];
            layer.percentage = (sum)?layer.value/sum:0;
            
            UIColor *color = [self colorForSliceAtIndex:index];
            [layer setFillColor:color.CGColor];
            
            if([self.dataSource respondsToSelector:@selector(pieChart:textForSliceAtIndex:)])
            {
                layer.text = [self.dataSource pieChart:self textForSliceAtIndex:index];
            }
            
            [self updateLabelForLayer:layer value:values[index]];
            [layer createArcAnimationForKey:@"startAngle"
                                  fromValue:[NSNumber numberWithDouble:startFromAngle]
                                    toValue:[NSNumber numberWithDouble:startToAngle+self.startPieAngle]
                                   Delegate:self];
            [layer createArcAnimationForKey:@"endAngle"
                                  fromValue:[NSNumber numberWithDouble:endFromAngle]
                                    toValue:[NSNumber numberWithDouble:endToAngle+self.startPieAngle]
                                   Delegate:self];
            startToAngle = endToAngle;
            
        }
        [CATransaction setDisableActions:YES];
        for(SliceLayer *layer in layersToRemove)
        {
            [layer setFillColor:[self backgroundColor].CGColor];
            [layer setDelegate:nil];
            [layer setZPosition:0];
            CATextLayer *textLayer = [[layer sublayers] objectAtIndex:0];
            [textLayer setHidden:YES];
        }
        
        [layersToRemove enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
        {
            [obj removeFromSuperlayer];
        }];
        
        [layersToRemove removeAllObjects];
        
        for(SliceLayer *layer in self.pieView.layer.sublayers)
        {
            [layer setZPosition:kDefaultSliceZOrder];
        }
        
        [self.pieView setUserInteractionEnabled:YES];
        
        [CATransaction setDisableActions:NO];
        [CATransaction commit];
    }
}

- (void)setDetailViewsVisibles:(BOOL)visibles
{
    NSArray *pieLayers = [self.pieView.layer sublayers];
    
    [pieLayers enumerateObjectsUsingBlock:^(CAShapeLayer * obj, NSUInteger idx, BOOL *stop)
     {
         if ([obj isKindOfClass:[SliceLayer class]])
         {
             SliceLayer* sliceLayer = (SliceLayer*)obj;
             if (visibles &&
                 [self.dataSource respondsToSelector:@selector(pieChart:detailViewForSliceAtIndex:andQuadrant:)])
             {
                 double middleAngle = (sliceLayer.startAngle+sliceLayer.endAngle)/2;
                 
                 
                 
                 sliceLayer.detailView = [self.dataSource pieChart:self
                                         detailViewForSliceAtIndex:idx
                                                       andQuadrant:XYPieChartQuadrantForAngle(middleAngle)];
                 if (sliceLayer.detailView)
                 {
                     CGFloat selectedSliceOffsetRadius = sliceLayer.isSelected ? self.selectedSliceOffsetRadius : 0;
                     CGFloat detailViewHalfWidth = sliceLayer.detailView.frame.size.width/2;
                     CGFloat detailViewHalfHeight = sliceLayer.detailView.frame.size.height/2;
                     CGFloat xOffset = ((cos(middleAngle) >= 0) ? 1 : -1)*detailViewHalfWidth;
                     CGFloat yOffset = ((sin(middleAngle) >= 0) ? 1 : -1)*detailViewHalfHeight;
                     CGFloat x = self.pieView.frame.origin.x + self.pieCenter.x + cos(middleAngle)*(self.pieOuterRadius + selectedSliceOffsetRadius) + xOffset;
                     CGFloat y = self.pieView.frame.origin.y + self.pieCenter.y + sin(middleAngle)*(self.pieOuterRadius + selectedSliceOffsetRadius) + yOffset;
                     
                     sliceLayer.detailView.center = CGPointMake((int)x, (int)y);
                     sliceLayer.detailView.alpha = 0;
                     [self addSubview:sliceLayer.detailView];
                     
                     [UIView animateWithDuration:self.animationSpeed
                                      animations:^{
                                          sliceLayer.detailView.alpha = 1;
                                      }];
                 }
             }
             else
             {
                 [UIView animateWithDuration:self.animationSpeed
                                  animations:^{
                                      sliceLayer.detailView.alpha = 0;
                                  } completion:^(BOOL finished) {
                                      [sliceLayer.detailView removeFromSuperview];
                                  }];
             }
         }
     }];
    
    
}

#pragma mark - Animation Delegate + Run Loop Timer

- (void)updateTimerFired:(NSTimer*)timer;
{
    CALayer *parentLayer = [self.pieView layer];
    NSArray *pieLayers = [parentLayer sublayers];
    
    [pieLayers enumerateObjectsUsingBlock:^(CAShapeLayer * obj, NSUInteger idx, BOOL *stop) {
        
        NSNumber *presentationLayerStartAngle = [[obj presentationLayer] valueForKey:@"startAngle"];
        CGFloat interpolatedStartAngle = [presentationLayerStartAngle doubleValue];
        
        NSNumber *presentationLayerEndAngle = [[obj presentationLayer] valueForKey:@"endAngle"];
        CGFloat interpolatedEndAngle = [presentationLayerEndAngle doubleValue];
        
        CGPathRef path = CGPathCreateArc(self.pieCenter, self.pieInnerRadius, self.pieOuterRadius, interpolatedStartAngle, interpolatedEndAngle);
        [obj setPath:path];
        CFRelease(path);
        
        {
            CALayer *labelLayer = [[obj sublayers] objectAtIndex:0];
            CGFloat interpolatedMidAngle = (interpolatedEndAngle + interpolatedStartAngle) / 2;
            [CATransaction setDisableActions:YES];
            [labelLayer setPosition:CGPointMake(self.pieCenter.x + (self.labelRadius * cos(interpolatedMidAngle)), self.pieCenter.y + (self.labelRadius * sin(interpolatedMidAngle)))];
            [CATransaction setDisableActions:NO];
        }
    }];
}

- (void)animationDidStart:(CAAnimation*)anim
{
    if (self.animationTimer == nil)
    {
        static float timeInterval = 1.0/60.0;
        // Run the animation timer on the main thread.
        // We want to allow the user to interact with the UI while this timer is running.
        // If we run it on this thread, the timer will be halted while the user is touching the screen (that's why the chart was disappearing in our collection view).
        self.animationTimer= [NSTimer timerWithTimeInterval:timeInterval target:self selector:@selector(updateTimerFired:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.animationTimer forMode:NSRunLoopCommonModes];
    }
    
    [self.animations addObject:anim];
}

- (void)animationDidStop:(CAAnimation*)anim finished:(BOOL)animationCompleted
{
    [self.animations removeObject:anim];
    
    if ([self.animations count] == 0)
    {
        [self.animationTimer invalidate];
        self.animationTimer = nil;
        
        if (self.shouldRotateWhenSliceSelected &&
            self.selectedSliceIndex != -1)
        {
            SliceLayer *layer = self.pieView.layer.sublayers[self.selectedSliceIndex];
            if (self.selectedSliceOffsetRadius > 0)
            {
                
                CGPoint currPos = layer.position;
                double middleAngle = (layer.startAngle + layer.endAngle)/2.0;
                CGPoint newPos = CGPointMake(currPos.x + self.selectedSliceOffsetRadius*cos(middleAngle), currPos.y + self.selectedSliceOffsetRadius*sin(middleAngle));
                layer.position = newPos;
            }
            layer.isSelected = YES;
        }
        
        [self setDetailViewsVisibles:YES];
    }
}

#pragma mark - Touch Handing (Selection Notification)

- (NSInteger)getCurrentSelectedOnTouch:(CGPoint)point
{
    __block NSUInteger selectedIndex = -1;
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    CALayer *parentLayer = [self.pieView layer];
    NSArray *pieLayers = [parentLayer sublayers];
    
    [pieLayers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
    {
        SliceLayer *pieLayer = (SliceLayer*)obj;
        CGPathRef path = [pieLayer path];
        
        if (CGPathContainsPoint(path, &transform, point, 0))
        {
            [pieLayer setLineWidth:self.selectedSliceStroke];
            [pieLayer setStrokeColor:[UIColor whiteColor].CGColor];
            [pieLayer setLineJoin:kCALineJoinBevel];
            [pieLayer setZPosition:MAXFLOAT];
            selectedIndex = idx;
        }
        else
        {
            [pieLayer setZPosition:kDefaultSliceZOrder];
            [pieLayer setLineWidth:0.0];
        }
    }];
    return selectedIndex;
}

- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    [self touchesMoved:touches withEvent:event];
}

- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.pieView];
    [self getCurrentSelectedOnTouch:point];
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.pieView];
    NSInteger selectedIndex = [self getCurrentSelectedOnTouch:point];
    [self notifyDelegateOfSelectionChangeFrom:self.selectedSliceIndex to:selectedIndex];
    [self touchesCancelled:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event
{
    CALayer *parentLayer = [self.pieView layer];
    NSArray *pieLayers = [parentLayer sublayers];
    
    for (SliceLayer *pieLayer in pieLayers)
    {
        [pieLayer setZPosition:kDefaultSliceZOrder];
        [pieLayer setLineWidth:0.0];
    }
}

#pragma mark - Selection Notification

- (void)notifyDelegateOfSelectionChangeFrom:(NSInteger)previousSelection to:(NSInteger)newSelection
{
    if (previousSelection != newSelection)
    {
        if(previousSelection != -1)
        {
            if ([self.delegate respondsToSelector:@selector(pieChart:willDeselectSliceAtIndex:)])
            {
                [self.delegate pieChart:self willDeselectSliceAtIndex:previousSelection];
            }
            [self setSliceDeselectedAtIndex:previousSelection];
            if([self.delegate respondsToSelector:@selector(pieChart:didDeselectSliceAtIndex:)])
            {
                [self.delegate pieChart:self didDeselectSliceAtIndex:previousSelection];
            }
        }
        
        if (newSelection != -1)
        {
            if([self.delegate respondsToSelector:@selector(pieChart:willSelectSliceAtIndex:)])
            {
                [self.delegate pieChart:self willSelectSliceAtIndex:newSelection];
            }
            [self setSliceSelectedAtIndex:newSelection];
            if([self.delegate respondsToSelector:@selector(pieChart:didSelectSliceAtIndex:)])
            {
                [self.delegate pieChart:self didSelectSliceAtIndex:newSelection];
            }
        }
    }
    else if (newSelection != -1)
    {
        SliceLayer *layer = [self.pieView.layer.sublayers objectAtIndex:newSelection];
        if(layer)
        {
            if (layer.isSelected)
            {
                if ([self.delegate respondsToSelector:@selector(pieChart:willDeselectSliceAtIndex:)])
                {
                    [self.delegate pieChart:self willDeselectSliceAtIndex:newSelection];
                }
                [self setSliceDeselectedAtIndex:previousSelection];
                if ([self.delegate respondsToSelector:@selector(pieChart:didDeselectSliceAtIndex:)])
                {
                    [self.delegate pieChart:self didDeselectSliceAtIndex:newSelection];
                }
            }
            else
            {
                if ([self.delegate respondsToSelector:@selector(pieChart:willSelectSliceAtIndex:)])
                {
                    [self.delegate pieChart:self willSelectSliceAtIndex:newSelection];
                }
                [self setSliceSelectedAtIndex:newSelection];
                if ([self.delegate respondsToSelector:@selector(pieChart:didSelectSliceAtIndex:)])
                    [self.delegate pieChart:self didSelectSliceAtIndex:newSelection];
            }
        }
    }
}
#pragma mark - Selection Programmatically Without Notification

- (void)setSliceSelectedAtIndex:(NSInteger)index
{
    SliceLayer *selectedSlicelayer = [self.pieView.layer.sublayers objectAtIndex:index];
    
    if (selectedSlicelayer && !selectedSlicelayer.isSelected)
    {
        if (self.shouldRotateWhenSliceSelected)
        {
            NSArray* sliceLayers = self.pieView.layer.sublayers;
            
                double sliceMiddleAngle = (selectedSlicelayer.startAngle+selectedSlicelayer.endAngle)/2;
                if (sliceMiddleAngle > 0)
                {
                    while (sliceMiddleAngle > M_PI) sliceMiddleAngle -= 2*M_PI;
                    self.currentPieOffsetAngle -= sliceMiddleAngle;
                }
                else
                {
                    while (sliceMiddleAngle < M_PI) sliceMiddleAngle += 2*M_PI;
                    self.currentPieOffsetAngle += 2*M_PI - sliceMiddleAngle;
                }
            
            __block double startToAngle = self.startPieAngle + self.currentPieOffsetAngle;
            __block double endToAngle = self.startPieAngle + self.currentPieOffsetAngle;
            selectedSlicelayer.isSelected = YES;
            
            [self setDetailViewsVisibles:NO];
            [CATransaction begin];
            [CATransaction setAnimationDuration:self.animationSpeed];
            
            [self.pieView setUserInteractionEnabled:NO];
            [sliceLayers enumerateObjectsUsingBlock:^(SliceLayer* layer, NSUInteger idx, BOOL *stop)
            {
                double sliceSizeAngle = layer.endAngle - layer.startAngle;
                endToAngle += sliceSizeAngle;
                
                [layer createArcAnimationForKey:@"startAngle"
                                      fromValue:[NSNumber numberWithDouble:layer.startAngle]
                                        toValue:[NSNumber numberWithDouble:startToAngle+self.startPieAngle]
                                       Delegate:self];
                [layer createArcAnimationForKey:@"endAngle"
                                      fromValue:[NSNumber numberWithDouble:layer.endAngle]
                                        toValue:[NSNumber numberWithDouble:endToAngle+self.startPieAngle]
                                       Delegate:self];
                startToAngle = endToAngle;
            }];
            
            [self.pieView setUserInteractionEnabled:YES];
            [CATransaction setDisableActions:NO];
            [CATransaction commit];
        }
        else if (self.selectedSliceOffsetRadius > 0)
        {
            CGPoint currPos = selectedSlicelayer.position;
            double middleAngle = (selectedSlicelayer.startAngle + selectedSlicelayer.endAngle)/2.0;
            CGPoint newPos = CGPointMake(currPos.x + self.selectedSliceOffsetRadius*cos(middleAngle), currPos.y + self.selectedSliceOffsetRadius*sin(middleAngle));
            selectedSlicelayer.position = newPos;
            selectedSlicelayer.isSelected = YES;
        }
        
        UIColor *color = [self colorForSliceAtIndex:index];
        [selectedSlicelayer setFillColor:color.CGColor];
        [self updateLabelColorForLayer:selectedSlicelayer];
    }
}

- (void)setSliceDeselectedAtIndex:(NSInteger)index
{
    SliceLayer *layer = [self.pieView.layer.sublayers objectAtIndex:index];
    
    if (layer && layer.isSelected)
    {
        layer.position = CGPointMake(0, 0);
        layer.isSelected = NO;
        
        UIColor *color = [self colorForSliceAtIndex:index];
        [layer setFillColor:color.CGColor];
        [self updateLabelColorForLayer:layer];
    }
}

#pragma mark - Pie Layer Creation Method

- (SliceLayer*)createSliceLayer
{
    SliceLayer *pieLayer = [SliceLayer layer];
    [pieLayer setZPosition:0];
    [pieLayer setStrokeColor:NULL];
    CATextLayer *textLayer = [CATextLayer layer];
    textLayer.contentsScale = [[UIScreen mainScreen] scale];
    CGFontRef font = nil;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
    {
        font = CGFontCreateCopyWithVariations((__bridge CGFontRef)(self.labelFont), (__bridge CFDictionaryRef)(@{}));
    }
    else
    {
        font = CGFontCreateWithFontName((__bridge CFStringRef)[self.labelFont fontName]);
    }
    if (font)
    {
        [textLayer setFont:font];
        CFRelease(font);
    }
    [textLayer setFontSize:self.labelFont.pointSize];
    [textLayer setAnchorPoint:CGPointMake(0.5, 0.5)];
    [textLayer setAlignmentMode:kCAAlignmentCenter];
    [textLayer setBackgroundColor:[UIColor clearColor].CGColor];
    [textLayer setForegroundColor:self.labelColor.CGColor];
    if (self.labelShadowColor)
    {
        [textLayer setShadowColor:self.labelShadowColor.CGColor];
        [textLayer setShadowOffset:CGSizeZero];
        [textLayer setShadowOpacity:1.0f];
        [textLayer setShadowRadius:2.0f];
    }
    CGSize size = [@"0" sizeWithFont:self.labelFont];
    [CATransaction setDisableActions:YES];
    [textLayer setFrame:CGRectMake(0, 0, size.width, size.height)];
    [textLayer setPosition:CGPointMake(self.pieCenter.x + (self.labelRadius * cos(0)), self.pieCenter.y + (self.labelRadius * sin(0)))];
    [CATransaction setDisableActions:NO];
    [pieLayer addSublayer:textLayer];
    return pieLayer;
}

- (UIColor*)colorForSliceAtIndex:(NSInteger)index
{
    UIColor *color = nil;
    
    if (index == self.selectedSliceIndex
        && self.selectedSliceColor)
    {
        color = self.selectedSliceColor;
    }
    else if([self.dataSource respondsToSelector:@selector(pieChart:colorForSliceAtIndex:)])
    {
        color = [self.dataSource pieChart:self colorForSliceAtIndex:index];
    }
    
    if(!color)
    {
        color = [UIColor colorWithHue:((index/8)%20)/20.0+0.02 saturation:(index%8+3)/10.0 brightness:91/100.0 alpha:1];
    }
    return color;
}

- (void)updateLabelForLayer:(SliceLayer*)pieLayer value:(CGFloat)value
{
    CATextLayer *textLayer = [[pieLayer sublayers] objectAtIndex:0];
    [textLayer setHidden:!self.showLabel];
    if(!self.showLabel) return;
    NSString *label;
    if(self.showPercentage)
        label = [NSString stringWithFormat:@"%0.0f", pieLayer.percentage*100];
    else
        label = (pieLayer.text)?pieLayer.text:[NSString stringWithFormat:@"%0.0f", value];
    
    CGSize size = [label sizeWithFont:self.labelFont];
    
    [CATransaction setDisableActions:YES];
    if(M_PI*2*self.labelRadius*pieLayer.percentage < MAX(size.width,size.height) || value <= 0)
    {
        [textLayer setString:@""];
    }
    else
    {
        [textLayer setString:label];
        [textLayer setBounds:CGRectMake(0, 0, size.width, size.height)];
    }
    
    
    
    [CATransaction setDisableActions:NO];
}

- (void)updateLabelColorForLayer:(SliceLayer*)pieLayer
{
    CATextLayer *textLayer = [[pieLayer sublayers] objectAtIndex:0];
    [CATransaction setDisableActions:YES];
    if (pieLayer.isSelected)
    {
        [textLayer setForegroundColor:self.labelSelectedColor.CGColor];
    }
    else
    {
        [textLayer setForegroundColor:self.labelColor.CGColor];
    }
    [CATransaction setDisableActions:NO];
}

@end