//
//  MinimapView.m
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import "MinimapView.h"
#import "NSView+Minimap.h"
#import "NSWindowController+Minimap.h"
#import "TextMate.h"
#import "TextmateMinimap.h"

@interface MinimapView (Private_TextHelp)
- (void)updateViewableRange;
- (int)getNumberOfLines;
- (void)drawFinished:(NSImage*) bitmap;
- (void)setPixelPerLine:(int)ppl; 
@end

@interface NSView (MM_NSView_OnlyByOakTextView)

- (unsigned int)lineHeight;

@end

@interface DrawOperation : NSOperation
{	
	MinimapView* minimapView;
	int pixelPerLine;
	NSRect rectToDrawTo;
}

- (id)initWithMinimapView:(MinimapView*)mv;
- (void)fullDraw;
- (void)partialDraw;

@end

@implementation DrawOperation

- (id)initWithMinimapView:(MinimapView*)mv
{
    if (![super init]) return nil;
    minimapView = [mv retain];
    return self;
}

- (void)dealloc {
    [minimapView release], minimapView = nil;
    [super dealloc];
}

- (NSBitmapImageRep*)cropImageRep:(NSBitmapImageRep*)rep ToRect:(NSRect)rect {
	CGImageRef cgImg = CGImageCreateWithImageInRect([rep CGImage], NSRectToCGRect(rect)); NSBitmapImageRep *result = [[NSBitmapImageRep alloc] initWithCGImage:cgImg];
	
	CGImageRelease(cgImg);          
	return [result autorelease];
}       

- (void)main {
	if ([self isCancelled]) 
		return;

	NSRect bounds = [minimapView bounds];
	
	rectToDrawTo = bounds;
	float numLines = [minimapView getNumberOfLines];

	pixelPerLine = bounds.size.height / numLines;
	if (pixelPerLine > 6) {
		float newHeight = 6*numLines;
		rectToDrawTo.size.height = newHeight;		
		rectToDrawTo.origin.y = bounds.size.height-newHeight;
		[minimapView setViewableRangeScaling:1.0];
		[minimapView setMinimapLinesStart:0];
		[self fullDraw];
	} 
	else if (pixelPerLine < 3)
	{
		[self partialDraw];
	}
	else
	{
		[minimapView setMinimapLinesStart:0];
		[minimapView setViewableRangeScaling:1.0];
		[self fullDraw];
	}
}

- (void) fullDraw
{
	NSRect bounds = [minimapView bounds];
	NSView* textView = [minimapView textView];
	NSBitmapImageRep* snapshot = [textView snapshot];
	
	NSColor* refColor = [[snapshot colorAtX:0 y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	int i = 1;
	NSColor* color = [[snapshot colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	while ([color isEqual:refColor]) {
		i++;
		color = [[snapshot colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	}
	
	if ([self isCancelled]) 
		return;

	NSBitmapImageRep* croppedSnapshot = [self cropImageRep:snapshot ToRect:NSMakeRect(i+1, 0, [snapshot size].width-(i+1), [snapshot size].height)];
		
	if ([self isCancelled]) 
		return;

	NSImage* image = [[[NSImage alloc] initWithSize:bounds.size] autorelease];
	[image setFlipped:YES];

	[image lockFocus];
		[croppedSnapshot drawInRect:rectToDrawTo];
	[image unlockFocus];
	
	if ([self isCancelled] || image == nil)
		return;

	[minimapView performSelectorOnMainThread:@selector(drawFinished:) withObject:image  waitUntilDone:FALSE];
}

- (void) partialDraw
{
	NSRect bounds = [minimapView bounds];
	NSView* textView = [minimapView textView];
	float numLines = [minimapView getNumberOfLines];
	NSRect tvBounds = [textView bounds];
	float visiblePercentage = bounds.size.height / (numLines*3);
	[minimapView setViewableRangeScaling:(1/visiblePercentage)];
	
	NSScrollView* sv = (NSScrollView*)[[textView superview] superview];
	float percentage = [[sv verticalScroller] floatValue];
	
	float middle = percentage*(tvBounds.size.height-[textView visibleRect].size.height) + [textView visibleRect].size.height/2;
	float mysteriousHeight = (visiblePercentage * tvBounds.size.height) - [textView visibleRect].size.height;
	float begin = middle - (percentage*mysteriousHeight) - ([textView visibleRect].size.height/2);

	NSRect rectToSnapshot = NSMakeRect( 51,
										begin,
										tvBounds.size.width,
										visiblePercentage * tvBounds.size.height);
	[minimapView setMinimapLinesStart:((begin/tvBounds.size.height)*numLines)];

	NSImage* snapshot = [textView snapshotByDrawingInRect:rectToSnapshot];
	
	NSImage* image = [[[NSImage alloc] initWithSize:bounds.size] autorelease];

	[image lockFocus];
		[snapshot drawInRect:rectToDrawTo fromRect:rectToSnapshot operation:NSCompositeCopy fraction:1.0];
	[image unlockFocus];
	
	[minimapView performSelectorOnMainThread:@selector(drawFinished:) withObject:image  waitUntilDone:FALSE];
}

@end


@implementation MinimapView

@synthesize windowController, theLock;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		_queue = [[NSOperationQueue alloc] init];
		[_queue setMaxConcurrentOperationCount:1];
		_refreshViewableRange = FALSE;
		_refreshAll = TRUE;
		_viewableRangeScale = 1.0;
		theLock = [[NSLock alloc] init];
	}
    return self;
}

- (void) viewDidEndLiveResize
{
	[self refreshDisplay];
}

- (id)initWithTextView:(NSView*) textView
{
    self = [super init];
    if (self) {
		_textView = [textView retain];
	}
    return self;
}

- (void)dealloc
{
	[super dealloc];
	[_queue release];
	_queue = nil;
	[_textView release];
	if (theLock)
	{
		[theLock release];theLock = nil;
	}
}

#pragma mark drawing routines

- (BOOL)isFlipped
{
	return YES;
}

- (BOOL)isOpaque 
{
    return YES;
}

- (void)drawRect:(NSRect)rect
{	
	if (![self inLiveResize] && _refreshAll) 
	{
		[_queue cancelAllOperations];
		DrawOperation* op = [[DrawOperation alloc] initWithMinimapView:self];
		[_queue addOperation:op];
		[op release];
		_refreshAll = FALSE;
	}
	[_nextImage drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];

	// drawing the vis rect
	[self updateViewableRange];
	NSRect bounds = [self bounds];
	float visRectHeight =_viewableRange.length*_pixelPerLine;
	float visRectPos;
	if (_viewableRangeScale != 1.0)
	{
		float rectProportion = visRectHeight / bounds.size.height;
		NSScrollView* sv = (NSScrollView*)[[_textView superview] superview];
		float percentage = [[sv verticalScroller] floatValue];
		float middle = percentage*(bounds.size.height-visRectHeight) + visRectHeight/2;
		float mysteriousHeight = (rectProportion * bounds.size.height) - visRectHeight;
		visRectPos = middle - (percentage*mysteriousHeight) - (visRectHeight/2);
	}
	else
	{
		visRectPos = (_viewableRange.location*_pixelPerLine);
	}
	NSRect visibleHighlightRect = NSMakeRect(0,
											 visRectPos,
											 rect.size.width-1,
											 visRectHeight);

	
	[NSGraphicsContext saveGraphicsState];
	[[NSColor colorWithCalibratedRed:0.549 green:0.756 blue:1 alpha:0.7] set];
	[NSBezierPath setDefaultLineWidth:1];
	[NSBezierPath strokeRect:visibleHighlightRect];
	[NSGraphicsContext restoreGraphicsState];
	
	_refreshViewableRange = FALSE;
}

- (void) updateViewableRange
{
	NSScrollView* sv = (NSScrollView*)[[_textView superview] superview];
	float proportion = [[sv verticalScroller] knobProportion];
	float percentage = [[sv verticalScroller] floatValue];
	int numLines = [self getNumberOfLines];
	int numVisLines = round(numLines * proportion);
	int middleLine = round(percentage*(numLines-numVisLines)+numVisLines/2);
	NSRange range = NSMakeRange(round(middleLine-(numVisLines/2)), numVisLines);

	if (range.location+range.length > [self getNumberOfLines])
	{
		range.location = [self getNumberOfLines]-range.length;
	}

	// find out whether a vertical scroller is displayed... strangely [sv hasVeticalScroller] always returns YES
	NSClipView* clipView = (NSClipView*)[[sv subviews] objectAtIndex:0];
	if ([clipView documentVisibleRect].size.height == [_textView bounds].size.height)
	{
		range.location = 0;
		range.length = numLines;
	}
	_viewableRange = range;
}

- (void) drawFinished: (NSImage*) bitmap 
{
	[_nextImage release];
	_nextImage = [bitmap retain];
	
	_pixelPerLine = [self bounds].size.height / [self getNumberOfLines];
	if (_pixelPerLine > 6)
	{
		_pixelPerLine = 6;
	}
	else if (_pixelPerLine < 3) {
		_pixelPerLine = 3;
	}
	[self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    BOOL keepOn = YES;
    BOOL isInside = YES;
    NSPoint mouseLoc;
    while (keepOn) {
        theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        isInside = [self mouse:mouseLoc inRect:[self bounds]];

		unsigned int relativelineIdx = floor(mouseLoc.y / _pixelPerLine);
		unsigned int absoluteLineIdx = _minimapLinesStart+relativelineIdx;
		NSLog(@"relativelineIdx: %i absoluteLineIdx %i linesStart %i", relativelineIdx, absoluteLineIdx, _minimapLinesStart);
        switch ([theEvent type]) {
            case NSLeftMouseDragged:
				[windowController scrollToLine:absoluteLineIdx];
				break;
            case NSLeftMouseUp:
				if (isInside){
					[windowController scrollToLine:absoluteLineIdx];
				}
				keepOn = NO;
				break;
            default:
				/* Ignore any other kind of event. */
				break;
        }
		
    };
    return;
}

#pragma mark public API
- (void)refreshDisplay{
	_refreshAll = TRUE;
	[self setNeedsDisplayInRect:[self visibleRect]];
}

- (void)refreshViewableRange{
	int pixelPerLine = [self bounds].size.height / [self getNumberOfLines];
	if (pixelPerLine < 3)
	{
		[self refreshDisplay];
	}
	_refreshViewableRange = TRUE;
	[self setNeedsDisplayInRect:[self visibleRect]];
}

- (NSRange)viewableRange
{
	return _viewableRange;
}
- (NSView*)textView
{
	return _textView;	
}
- (void)setPixelPerLine:(int)ppl
{
	_pixelPerLine = ppl;
}

- (void)setViewableRangeScaling:(float)scale
{
	_viewableRangeScale = scale;
}
- (void)setMinimapLinesStart:(int)start
{
	NSLog(@"setting linesstart %i", start);
	_minimapLinesStart = start;
}

- (int) getNumberOfLines
{
	unsigned int lineHeight = [_textView lineHeight];
 
	float h = [_textView bounds].size.height;
	int totalLines = round(h/lineHeight);
	return totalLines;
}

@end
