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
#import "AsyncDrawOperation.h"

int const scaleDownThreshold = 6;
int const scaleDownTo = 6;

@interface MinimapView (Private_MinimapView)
- (void)updateViewableRange;
- (void)drawVisRect:(NSRect)rect;
@end

@interface NSView (MM_NSView_OnlyByOakTextView)
- (unsigned int)lineHeight;
@end

@implementation MinimapView

@synthesize windowController, gutterSize, textView;

#pragma mark init

- (id)initWithTextView:(NSView*) tv
{
    self = [super init];
    if (self) {
		queue = [[NSOperationQueue alloc] init];
		[queue setMaxConcurrentOperationCount:1];
		refreshAll = TRUE;
		viewableRangeScale = 1.0;
		gutterSize = -1;
		textView = [tv retain];
	}
    return self;
}

- (void)dealloc
{
	[super dealloc];
	[queue release];
	queue = nil;
	[textView release];
	[nextImage release];
	[windowController release];
}

#pragma mark drawing routines

- (void)drawRect:(NSRect)rect
{	
	if (![self inLiveResize] && refreshAll) 
	{
		[queue cancelAllOperations];
		AsyncDrawOperation* op = [[AsyncDrawOperation alloc] initWithMinimapView:self];
		[queue addOperation:op];
		[op release];
		refreshAll = FALSE;
	}
	
	[nextImage drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	
	[self drawVisRect:rect];
}

- (void) updateViewableRange
{
	NSScrollView* sv = (NSScrollView*)[[textView superview] superview];
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
	if ([clipView documentVisibleRect].size.height == [textView bounds].size.height)
	{
		range.location = 0;
		range.length = numLines;
	}
	viewableRange = range;
}

- (void)drawVisRect:(NSRect)rect
{
	// drawing the vis rect
	[self updateViewableRange];
	NSRect bounds = [self bounds];
	float visRectHeight = viewableRange.length * pixelPerLine;
	float visRectPos;
	if (viewableRangeScale != 1.0)
	{
		float rectProportion = visRectHeight / bounds.size.height;
		NSScrollView* sv = (NSScrollView*)[[textView superview] superview];
		float percentage = [[sv verticalScroller] floatValue];
		float middle = percentage*(bounds.size.height-visRectHeight) + visRectHeight/2;
		float mysteriousHeight = (rectProportion * bounds.size.height) - visRectHeight;
		visRectPos = middle - (percentage*mysteriousHeight) - (visRectHeight/2);
	}
	else
	{
		visRectPos = (viewableRange.location*pixelPerLine);
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

		unsigned int relativelineIdx = floor(mouseLoc.y / pixelPerLine);
		unsigned int absoluteLineIdx = minimapLinesStart+relativelineIdx;
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

- (void) viewDidEndLiveResize
{
	[self refreshDisplay];
}
- (BOOL)isFlipped
{
	return YES;
}
- (BOOL)isOpaque 
{
    return YES;
}


#pragma mark public API

- (void)refreshDisplay{
	refreshAll = TRUE;
	[self setNeedsDisplayInRect:[self visibleRect]];
}
- (void)refreshViewableRange{
	int ppl = [self bounds].size.height / [self getNumberOfLines];
	float scaleUpThreshold = [[NSUserDefaults standardUserDefaults] floatForKey:@"Minimap_scaleUpThreshold"];
	if (ppl < scaleUpThreshold)
	{
		[self refreshDisplay];
	}
	else
	{
		[self setNeedsDisplayInRect:[self visibleRect]];
	}
}
- (void)updateGutterSize
{
	int w = [textView bounds].size.width;
	NSBitmapImageRep* rawImg = [textView snapshotInRect:NSMakeRect(0	,0,w,1)];
	NSColor* refColor = [[rawImg colorAtX:0 y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

	int i = 1;
	NSColor* color = [[rawImg colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	while ([color isEqual:refColor]) {
		i++;
		color = [[rawImg colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	}
	gutterSize = i+1;
}

#pragma mark drawOperation-api

- (void)asyncDrawFinished: (NSImage*) bitmap 
{
	[nextImage release];
	nextImage = [bitmap retain];
	
	pixelPerLine = [self bounds].size.height / [self getNumberOfLines];
	int scaleUpTo = [[NSUserDefaults standardUserDefaults] integerForKey:@"Minimap_scaleUpTo"];
	float scaleUpThreshold = [[NSUserDefaults standardUserDefaults] floatForKey:@"Minimap_scaleUpThreshold"];
	
	if (pixelPerLine > scaleDownThreshold)
	{
		pixelPerLine = scaleDownTo;
	}
	else if (pixelPerLine < scaleUpThreshold) {
		pixelPerLine = scaleUpTo;
	}
	[self setNeedsDisplay:YES];
}
- (void)setViewableRangeScaling:(float)scale
{
	viewableRangeScale = scale;
}
- (void)setMinimapLinesStart:(int)start
{
	minimapLinesStart = start;
}
- (int)getNumberOfLines
{
	unsigned int lineHeight = [textView lineHeight];
 
	float h = [textView bounds].size.height;
	int totalLines = round(h/lineHeight);
	return totalLines;
}

@end
