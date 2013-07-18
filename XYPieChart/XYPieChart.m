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
- (void)createArcAnimationForKey:(NSString *)key fromValue:(NSNumber *)from toValue:(NSNumber *)to Delegate:(id)delegate;
@end

@implementation SliceLayer
@synthesize text = _text;
@synthesize value = _value;
@synthesize percentage = _percentage;
@synthesize startAngle = _startAngle;
@synthesize endAngle = _endAngle;
@synthesize isSelected = _isSelected;
- (NSString*)description
{
    return [NSString stringWithFormat:@"value:%f, percentage:%0.0f, start:%f, end:%f", _value, _percentage, _startAngle/M_PI*180, _endAngle/M_PI*180];
}
+ (BOOL)needsDisplayForKey:(NSString *)key 
{
    if ([key isEqualToString:@"startAngle"] || [key isEqualToString:@"endAngle"]) {
        return YES;
    }
    else {
        return [super needsDisplayForKey:key];
    }
}
- (id)initWithLayer:(id)layer
{
    if (self = [super initWithLayer:layer])
    {
        if ([layer isKindOfClass:[SliceLayer class]]) {
            self.startAngle = [(SliceLayer *)layer startAngle];
            self.endAngle = [(SliceLayer *)layer endAngle];
        }
    }
    return self;
}
- (void)createArcAnimationForKey:(NSString *)key fromValue:(NSNumber *)from toValue:(NSNumber *)to Delegate:(id)delegate
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

@interface XYPieChart (Private) 
- (void)updateTimerFired:(NSTimer *)timer;
- (SliceLayer *)createSliceLayer;
- (CGSize)sizeThatFitsString:(NSString *)string;
- (void)updateLabelForLayer:(SliceLayer *)pieLayer value:(CGFloat)value;
- (void)notifyDelegateOfSelectionChangeFrom:(NSUInteger)previousSelection to:(NSUInteger)newSelection;
@end

@implementation XYPieChart
{
    NSInteger _selectedSliceIndex;
    //pie view, contains all slices
    UIView  *_pieView;
    
    //animation control
    NSTimer *_animationTimer;
    NSMutableArray *_animations;
}

static NSUInteger kDefaultSliceZOrder = 100;

@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize startPieAngle = _startPieAngle;
@synthesize animationSpeed = _animationSpeed;
@synthesize pieCenter = _pieCenter;
@synthesize pieRadius = _pieRadius;
@synthesize showLabel = _showLabel;
@synthesize labelFont = _labelFont;
@synthesize labelColor = _labelColor;
@synthesize labelShadowColor = _labelShadowColor;
@synthesize labelRadius = _labelRadius;
@synthesize selectedSliceStroke = _selectedSliceStroke;
@synthesize selectedSliceOffsetRadius = _selectedSliceOffsetRadius;
@synthesize showPercentage = _showPercentage;

static CGPathRef CGPathCreateArc(CGPoint center, CGFloat radius, CGFloat startAngle, CGFloat endAngle) 
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, center.x, center.y);
    
    CGPathAddArc(path, NULL, center.x, center.y, radius, startAngle, endAngle, 0);
    CGPathCloseSubpath(path);
    
    return path;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.backgroundColor = [UIColor clearColor];
        _pieView = [[UIView alloc] initWithFrame:frame];
        [_pieView setBackgroundColor:[UIColor clearColor]];
        [self addSubview:_pieView];
        
        _selectedSliceIndex = -1;
        _animations = [[NSMutableArray alloc] init];
        
        _animationSpeed = 0.5;
        _startPieAngle = M_PI_2*3;
        _selectedSliceStroke = 3.0;
        
        self.pieRadius = MIN(frame.size.width/2, frame.size.height/2) - 10;
        self.pieCenter = CGPointMake(frame.size.width/2, frame.size.height/2);
        self.labelFont = [UIFont boldSystemFontOfSize:MAX((int)self.pieRadius/10, 5)];
        _labelColor = [UIColor whiteColor];
        _labelRadius = _pieRadius/2;
        _selectedSliceOffsetRadius = MAX(10, _pieRadius/10);
        
        _showLabel = YES;
        _showPercentage = YES;
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame Center:(CGPoint)center Radius:(CGFloat)radius
{
    self = [self initWithFrame:frame];
    if (self)
    {
        self.pieCenter = center;
        self.pieRadius = radius;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self)
    {
        _pieView = [[UIView alloc] initWithFrame:self.bounds];
        [_pieView setBackgroundColor:[UIColor clearColor]];
        [self insertSubview:_pieView atIndex:0];
        
        _selectedSliceIndex = -1;
        _animations = [[NSMutableArray alloc] init];
        
        _animationSpeed = 0.5;
        _startPieAngle = M_PI_2*3;
        _selectedSliceStroke = 3.0;
        
        CGRect bounds = [[self layer] bounds];
        self.pieRadius = MIN(bounds.size.width/2, bounds.size.height/2) - 10;
        self.pieCenter = CGPointMake(bounds.size.width/2, bounds.size.height/2);
        self.labelFont = [UIFont boldSystemFontOfSize:MAX((int)self.pieRadius/10, 5)];
        _labelColor = [UIColor whiteColor];
        _labelRadius = _pieRadius/2;
        _selectedSliceOffsetRadius = MAX(10, _pieRadius/10);
        
        _showLabel = YES;
        _showPercentage = YES;
    }
    return self;
}

- (void)setPieCenter:(CGPoint)pieCenter
{
    [_pieView setCenter:pieCenter];
    _pieCenter = CGPointMake(_pieView.frame.size.width/2, _pieView.frame.size.height/2);
}

- (void)setPieRadius:(CGFloat)pieRadius
{
    _pieRadius = pieRadius;
    CGPoint origin = _pieView.frame.origin;
    CGRect frame = CGRectMake(origin.x+_pieCenter.x-pieRadius, origin.y+_pieCenter.y-pieRadius, pieRadius*2, pieRadius*2);
    _pieCenter = CGPointMake(frame.size.width/2, frame.size.height/2);
    [_pieView setFrame:frame];
    [_pieView.layer setCornerRadius:_pieRadius];
}

- (void)setPieBackgroundColor:(UIColor *)color
{
    [_pieView setBackgroundColor:color];
}

#pragma mark - manage settings

- (void)setShowPercentage:(BOOL)showPercentage
{
    _showPercentage = showPercentage;
    for(SliceLayer *layer in _pieView.layer.sublayers)
    {
        CATextLayer *textLayer = [[layer sublayers] objectAtIndex:0];
        [textLayer setHidden:!_showLabel];
        if(!_showLabel) return;
        NSString *label;
        if(_showPercentage)
            label = [NSString stringWithFormat:@"%0.0f", layer.percentage*100];
        else
            label = (layer.text)?layer.text:[NSString stringWithFormat:@"%0.0f", layer.value];
        CGSize size = [label sizeWithFont:self.labelFont];
        
        if(M_PI*2*_labelRadius*layer.percentage < MAX(size.width,size.height))
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
    if (_dataSource)
    {
        CALayer *parentLayer = [_pieView layer];
        NSArray *slicelayers = [parentLayer sublayers];
        
        _selectedSliceIndex = -1;
        [slicelayers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            SliceLayer *layer = (SliceLayer *)obj;
            if(layer.isSelected)
                [self setSliceDeselectedAtIndex:idx];
        }];
        
        double startToAngle = 0.0;
        double endToAngle = startToAngle;
        
        NSUInteger sliceCount = [_dataSource numberOfSlicesInPieChart:self];
        
        double sum = 0.0;
        double values[sliceCount];
        for (int index = 0; index < sliceCount; index++) {
            values[index] = [_dataSource pieChart:self valueForSliceAtIndex:index];
            sum += values[index];
        }
        
        double angles[sliceCount];
        for (int index = 0; index < sliceCount; index++) {
            double div;
            if (sum == 0)
                div = 0;
            else
                div = values[index] / sum; 
            angles[index] = M_PI * 2 * div;
        }

        [CATransaction begin];
        [CATransaction setAnimationDuration:_animationSpeed];
        
        [_pieView setUserInteractionEnabled:NO];
        
        __block NSMutableArray *layersToRemove = nil;
        
        BOOL isOnStart = ([slicelayers count] == 0 && sliceCount);
        NSInteger diff = sliceCount - [slicelayers count];
        layersToRemove = [NSMutableArray arrayWithArray:slicelayers];
        
        BOOL isOnEnd = ([slicelayers count] && (sliceCount == 0 || sum <= 0));
        if(isOnEnd)
        {
            for(SliceLayer *layer in _pieView.layer.sublayers){
                [self updateLabelForLayer:layer value:0];
                [layer createArcAnimationForKey:@"startAngle"
                                      fromValue:[NSNumber numberWithDouble:_startPieAngle]
                                        toValue:[NSNumber numberWithDouble:_startPieAngle] 
                                       Delegate:self];
                [layer createArcAnimationForKey:@"endAngle" 
                                      fromValue:[NSNumber numberWithDouble:_startPieAngle]
                                        toValue:[NSNumber numberWithDouble:_startPieAngle] 
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
            double startFromAngle = _startPieAngle + startToAngle;
            double endFromAngle = _startPieAngle + endToAngle;
            
            if( index >= [slicelayers count] )
            {
                layer = [self createSliceLayer];
                if (isOnStart)
                    startFromAngle = endFromAngle = _startPieAngle;
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
            UIColor *color = nil;
            if([_dataSource respondsToSelector:@selector(pieChart:colorForSliceAtIndex:)])
            {
                color = [_dataSource pieChart:self colorForSliceAtIndex:index];
            }
            
            if(!color)
            {
                color = [UIColor colorWithHue:((index/8)%20)/20.0+0.02 saturation:(index%8+3)/10.0 brightness:91/100.0 alpha:1];
            }
            
            [layer setFillColor:color.CGColor];
            if([_dataSource respondsToSelector:@selector(pieChart:textForSliceAtIndex:)])
            {
                layer.text = [_dataSource pieChart:self textForSliceAtIndex:index];
            }
            
            [self updateLabelForLayer:layer value:values[index]];
            [layer createArcAnimationForKey:@"startAngle"
                                  fromValue:[NSNumber numberWithDouble:startFromAngle]
                                    toValue:[NSNumber numberWithDouble:startToAngle+_startPieAngle] 
                                   Delegate:self];
            [layer createArcAnimationForKey:@"endAngle" 
                                  fromValue:[NSNumber numberWithDouble:endFromAngle]
                                    toValue:[NSNumber numberWithDouble:endToAngle+_startPieAngle] 
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
        
        [layersToRemove enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj removeFromSuperlayer];
        }];
        
        [layersToRemove removeAllObjects];
        
        for(SliceLayer *layer in _pieView.layer.sublayers)
        {
            [layer setZPosition:kDefaultSliceZOrder];
        }
        
        [_pieView setUserInteractionEnabled:YES];
        
        [CATransaction setDisableActions:NO];
        [CATransaction commit];
    }
}

#pragma mark - Animation Delegate + Run Loop Timer

- (void)updateTimerFired:(NSTimer *)timer;
{   
    CALayer *parentLayer = [_pieView layer];
    NSArray *pieLayers = [parentLayer sublayers];

    [pieLayers enumerateObjectsUsingBlock:^(CAShapeLayer * obj, NSUInteger idx, BOOL *stop) {
        
        NSNumber *presentationLayerStartAngle = [[obj presentationLayer] valueForKey:@"startAngle"];
        CGFloat interpolatedStartAngle = [presentationLayerStartAngle doubleValue];
        
        NSNumber *presentationLayerEndAngle = [[obj presentationLayer] valueForKey:@"endAngle"];
        CGFloat interpolatedEndAngle = [presentationLayerEndAngle doubleValue];

        CGPathRef path = CGPathCreateArc(_pieCenter, _pieRadius, interpolatedStartAngle, interpolatedEndAngle);
        [obj setPath:path];
        CFRelease(path);
        
        {
            CALayer *labelLayer = [[obj sublayers] objectAtIndex:0];
            CGFloat interpolatedMidAngle = (interpolatedEndAngle + interpolatedStartAngle) / 2;        
            [CATransaction setDisableActions:YES];
            [labelLayer setPosition:CGPointMake(_pieCenter.x + (_labelRadius * cos(interpolatedMidAngle)), _pieCenter.y + (_labelRadius * sin(interpolatedMidAngle)))];
            [CATransaction setDisableActions:NO];
        }
    }];
}

- (void)animationDidStart:(CAAnimation *)anim
{
    if (_animationTimer == nil) {
        static float timeInterval = 1.0/60.0;
        // Run the animation timer on the main thread.
        // We want to allow the user to interact with the UI while this timer is running.
        // If we run it on this thread, the timer will be halted while the user is touching the screen (that's why the chart was disappearing in our collection view).
        _animationTimer= [NSTimer timerWithTimeInterval:timeInterval target:self selector:@selector(updateTimerFired:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_animationTimer forMode:NSRunLoopCommonModes];
    }
    
    [_animations addObject:anim];
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)animationCompleted
{
    [_animations removeObject:anim];
    
    if ([_animations count] == 0) {
        [_animationTimer invalidate];
        _animationTimer = nil;
    }
}

#pragma mark - Touch Handing (Selection Notification)

- (NSInteger)getCurrentSelectedOnTouch:(CGPoint)point
{
    __block NSUInteger selectedIndex = -1;
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    CALayer *parentLayer = [_pieView layer];
    NSArray *pieLayers = [parentLayer sublayers];
    
    [pieLayers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SliceLayer *pieLayer = (SliceLayer *)obj;
        CGPathRef path = [pieLayer path];
        
        if (CGPathContainsPoint(path, &transform, point, 0)) {
            [pieLayer setLineWidth:_selectedSliceStroke];
            [pieLayer setStrokeColor:[UIColor whiteColor].CGColor];
            [pieLayer setLineJoin:kCALineJoinBevel];
            [pieLayer setZPosition:MAXFLOAT];
            selectedIndex = idx;
        } else {
            [pieLayer setZPosition:kDefaultSliceZOrder];
            [pieLayer setLineWidth:0.0];
        }
    }];
    return selectedIndex;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:_pieView];
    [self getCurrentSelectedOnTouch:point];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:_pieView];
    NSInteger selectedIndex = [self getCurrentSelectedOnTouch:point];
    [self notifyDelegateOfSelectionChangeFrom:_selectedSliceIndex to:selectedIndex];
    [self touchesCancelled:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    CALayer *parentLayer = [_pieView layer];
    NSArray *pieLayers = [parentLayer sublayers];
    
    for (SliceLayer *pieLayer in pieLayers) {
        [pieLayer setZPosition:kDefaultSliceZOrder];
        [pieLayer setLineWidth:0.0];
    }
}

#pragma mark - Selection Notification

- (void)notifyDelegateOfSelectionChangeFrom:(NSUInteger)previousSelection to:(NSUInteger)newSelection
{
    if (previousSelection != newSelection){
        if(previousSelection != -1){
            NSUInteger tempPre = previousSelection;
            if ([_delegate respondsToSelector:@selector(pieChart:willDeselectSliceAtIndex:)])
                [_delegate pieChart:self willDeselectSliceAtIndex:tempPre];
            [self setSliceDeselectedAtIndex:tempPre];
            previousSelection = newSelection;
            if([_delegate respondsToSelector:@selector(pieChart:didDeselectSliceAtIndex:)])
                [_delegate pieChart:self didDeselectSliceAtIndex:tempPre];
        }
        
        if (newSelection != -1){
            if([_delegate respondsToSelector:@selector(pieChart:willSelectSliceAtIndex:)])
                [_delegate pieChart:self willSelectSliceAtIndex:newSelection];
            [self setSliceSelectedAtIndex:newSelection];
            _selectedSliceIndex = newSelection;
            if([_delegate respondsToSelector:@selector(pieChart:didSelectSliceAtIndex:)])
                [_delegate pieChart:self didSelectSliceAtIndex:newSelection];
        }
    }else if (newSelection != -1){
        SliceLayer *layer = [_pieView.layer.sublayers objectAtIndex:newSelection];
        if(_selectedSliceOffsetRadius > 0 && layer){
            if (layer.isSelected) {
                if ([_delegate respondsToSelector:@selector(pieChart:willDeselectSliceAtIndex:)])
                    [_delegate pieChart:self willDeselectSliceAtIndex:newSelection];
                [self setSliceDeselectedAtIndex:newSelection];
                if (newSelection != -1 && [_delegate respondsToSelector:@selector(pieChart:didDeselectSliceAtIndex:)])
                    [_delegate pieChart:self didDeselectSliceAtIndex:newSelection];
                previousSelection = _selectedSliceIndex = -1;
            }else{
                if ([_delegate respondsToSelector:@selector(pieChart:willSelectSliceAtIndex:)])
                    [_delegate pieChart:self willSelectSliceAtIndex:newSelection];
                [self setSliceSelectedAtIndex:newSelection];
                previousSelection = _selectedSliceIndex = newSelection;
                if (newSelection != -1 && [_delegate respondsToSelector:@selector(pieChart:didSelectSliceAtIndex:)])
                    [_delegate pieChart:self didSelectSliceAtIndex:newSelection];
            }
        }
    }
}
#pragma mark - Selection Programmatically Without Notification

- (void)setSliceSelectedAtIndex:(NSInteger)index
{
    if(_selectedSliceOffsetRadius <= 0)
        return;
    SliceLayer *layer = [_pieView.layer.sublayers objectAtIndex:index];
    if (layer && !layer.isSelected) {
        CGPoint currPos = layer.position;
        double middleAngle = (layer.startAngle + layer.endAngle)/2.0;
        CGPoint newPos = CGPointMake(currPos.x + _selectedSliceOffsetRadius*cos(middleAngle), currPos.y + _selectedSliceOffsetRadius*sin(middleAngle));
        layer.position = newPos;
        layer.isSelected = YES;
    }
}

- (void)setSliceDeselectedAtIndex:(NSInteger)index
{
    if(_selectedSliceOffsetRadius <= 0)
        return;
    SliceLayer *layer = [_pieView.layer.sublayers objectAtIndex:index];
    if (layer && layer.isSelected) {
        layer.position = CGPointMake(0, 0);
        layer.isSelected = NO;
    }
}

#pragma mark - Pie Layer Creation Method

- (SliceLayer *)createSliceLayer
{
    SliceLayer *pieLayer = [SliceLayer layer];
    [pieLayer setZPosition:0];
    [pieLayer setStrokeColor:NULL];
    CATextLayer *textLayer = [CATextLayer layer];
    textLayer.contentsScale = [[UIScreen mainScreen] scale];
    CGFontRef font = nil;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        font = CGFontCreateCopyWithVariations((__bridge CGFontRef)(self.labelFont), (__bridge CFDictionaryRef)(@{}));
    } else {
        font = CGFontCreateWithFontName((__bridge CFStringRef)[self.labelFont fontName]);
    }
    if (font) {
        [textLayer setFont:font];
        CFRelease(font);
    }
    [textLayer setFontSize:self.labelFont.pointSize];
    [textLayer setAnchorPoint:CGPointMake(0.5, 0.5)];
    [textLayer setAlignmentMode:kCAAlignmentCenter];
    [textLayer setBackgroundColor:[UIColor clearColor].CGColor];
    [textLayer setForegroundColor:self.labelColor.CGColor];
    if (self.labelShadowColor) {
        [textLayer setShadowColor:self.labelShadowColor.CGColor];
        [textLayer setShadowOffset:CGSizeZero];
        [textLayer setShadowOpacity:1.0f];
        [textLayer setShadowRadius:2.0f];
    }
    CGSize size = [@"0" sizeWithFont:self.labelFont];
    [CATransaction setDisableActions:YES];
    [textLayer setFrame:CGRectMake(0, 0, size.width, size.height)];
    [textLayer setPosition:CGPointMake(_pieCenter.x + (_labelRadius * cos(0)), _pieCenter.y + (_labelRadius * sin(0)))];
    [CATransaction setDisableActions:NO];
    [pieLayer addSublayer:textLayer];
    return pieLayer;
}

- (void)updateLabelForLayer:(SliceLayer *)pieLayer value:(CGFloat)value
{
    CATextLayer *textLayer = [[pieLayer sublayers] objectAtIndex:0];
    [textLayer setHidden:!_showLabel];
    if(!_showLabel) return;
    NSString *label;
    if(_showPercentage)
        label = [NSString stringWithFormat:@"%0.0f", pieLayer.percentage*100];
    else
        label = (pieLayer.text)?pieLayer.text:[NSString stringWithFormat:@"%0.0f", value];
    
    CGSize size = [label sizeWithFont:self.labelFont];
    
    [CATransaction setDisableActions:YES];
    if(M_PI*2*_labelRadius*pieLayer.percentage < MAX(size.width,size.height) || value <= 0)
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

@end
