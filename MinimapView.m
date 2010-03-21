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
#import "AsyncDrawOperation.h"

int const scaleDownThreshold = 6;
int const scaleDownTo = 6;

@interface MinimapView (Private_MinimapView)
- (void)updateViewableRange;
- (void)drawVisRect:(NSRect)rect;
- (NSRect)updateVisiblePartOfImage;
- (NSColor*)currentBackgroundColor;
@end

@interface NSView (MM_NSView_OnlyByOakTextView)
- (unsigned int)lineHeight;
- (id)currentStyleSheet;
@end

@implementation MinimapView

@synthesize windowController, textView, theImage, timer, drawLock;

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
		firstDraw = YES;
		timer = NULL;
		updater = [[BackgroundUpdater alloc] initWithMinimapView:self andOperationQueue:queue];
	}
    return self;
}

- (void)dealloc
{
	[queue cancelAllOperations];
	[queue waitUntilAllOperationsAreFinished];
	[textView release];
	[windowController release];
	[theImage release];
	[updater release];
	[queue release];
	queue = nil;
	[super dealloc];
}

#pragma mark drawing routines

- (void)drawRect:(NSRect)rect
{	
	if (firstDraw) {
		[windowController updateTrailingSpace];
		firstDraw = NO;
		theImage = [[textView emptySnapshotImageFor:self] retain];
		refreshAll = YES;
	}
	
	int numLines = [self getNumberOfLines];
	float ppl = [self bounds].size.height / numLines;
	float scaleUpThreshold = [[NSUserDefaults standardUserDefaults] floatForKey:@"Minimap_scaleUpThreshold"];
	
	if (refreshAll) 
	{
		AsyncDrawOperation* op;
		if (ppl < scaleUpThreshold)
		{
			NSRect rectToSnapshot = [self updateVisiblePartOfImage];
			op = [[AsyncDrawOperation alloc] initWithMinimapView:self andMode:MM_PARTIAL_IMAGE];
			[op setPartToDraw:rectToSnapshot];
			refreshAll = NO;
		} else {
			op = [[AsyncDrawOperation alloc] initWithMinimapView:self andMode:MM_COMPLETE_IMAGE];
		}
		[queue cancelAllOperations];
		[queue addOperation:op];
		[op release];
		refreshAll = NO;
		
	}
	if (ppl < scaleUpThreshold)
	{
		NSRect rectToSnapshot = [self updateVisiblePartOfImage];
		[theImage drawInRect:[self bounds] fromRect:rectToSnapshot operation:NSCompositeSourceOver fraction:1.0];
	}
	else
	{
		[self setMinimapLinesStart:0];
		[self setViewableRangeScaling:1.0];
		[theImage drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	}
	[self drawVisRect:rect];
}

- (NSRect) updateVisiblePartOfImage 
{
	NSRect bounds = [self bounds];
	int numLines = [self getNumberOfLines];

	NSSize imgSize = [theImage size];	
	NSRect tvBounds		= [textView bounds];
	int scaleUpTo = [[NSUserDefaults standardUserDefaults] integerForKey:@"Minimap_scaleUpTo"];
	pixelPerLine = scaleUpTo;
	float visiblePercentage = bounds.size.height / (numLines*scaleUpTo);
	[self setViewableRangeScaling:(1/visiblePercentage)];
	
	NSScrollView* sv = (NSScrollView*)[[textView superview] superview];
	float percentage = [[sv verticalScroller] floatValue];
	
	float scaleFactor = [theImage size].height / tvBounds.size.height;			
	float middle = (percentage*(tvBounds.size.height-[textView visibleRect].size.height) + [textView visibleRect].size.height/2);
	float mysteriousHeight = ((visiblePercentage * tvBounds.size.height) - [textView visibleRect].size.height);
	float begin = middle - (percentage*mysteriousHeight) - ([textView visibleRect].size.height/2);
	
	NSRect visRect = NSMakeRect(0,
									   begin*scaleFactor,
									   [theImage size].width,
									   (visiblePercentage * imgSize.height));
	[self setMinimapLinesStart:(begin/tvBounds.size.height)*numLines];
	visiblePartOfImage = visRect;
	return visRect;
}
- (NSRect)getVisiblePartOfMinimap
{
	return visiblePartOfImage;
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

- (void)refreshDisplay {
	refreshAll = TRUE;
	[self setNeedsDisplayInRect:[self visibleRect]];
}
- (void)refreshViewableRange{
	[self setNeedsDisplayInRect:[self visibleRect]];
	
	/*
	NSTimer* old_timer = [self timer];
	if (old_timer != NULL && [old_timer isValid]) {
		[old_timer invalidate];
	}
	// do not refresh instantly, wait until scrolling finished
	NSTimer* t = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(refreshDisplay) userInfo:nil repeats:NO];
	[self setTimer:t];
	 */
}
- (void)updateGutterSize
{
	int w = [textView bounds].size.width;
	NSBitmapImageRep* rawImg = [textView snapshotInRect:NSMakeRect(0,0,w,1)];
	NSColor* refColor = [self currentBackgroundColor];

	int i = 1;
	NSColor* color = [[rawImg colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	while (![color isEqual:refColor]) {
		i++;
		color = [[rawImg colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	}
	gutterSize = i+1;
}
- (void)setNewDocument
{
		[theImage release];
	theImage = NULL;
	firstDraw = YES;
}

- (NSColor*)currentBackgroundColor
{
	id stylesheet = [textView currentStyleSheet];
	NSDictionary* firstEntry = [(NSArray*)stylesheet objectAtIndex:0]; // the first entry seems to always contain the main settings
	NSString* bgColor = [[firstEntry objectForKey:@"settings"] objectForKey:@"background"];
	unsigned aValue = strtoul([[bgColor substringWithRange:NSMakeRange(1, 6)] UTF8String], NULL, 16);
	CGFloat red = ((CGFloat)((aValue & 0xFF0000) >> 16)) / 255.0f;
	CGFloat green = ((CGFloat)((aValue & 0xFF00) >> 8)) / 255.0f;
	CGFloat blue = (CGFloat)(aValue & 0xFF) / 255.0f;
	CGFloat alpha = 1.0;
	if ([bgColor length] == 9) //  if a alpha was given
	{
		unsigned alphaValue = strtoul([[bgColor substringWithRange:NSMakeRange(7, 2)] UTF8String], NULL, 16);
		alpha = (CGFloat)(alphaValue & 0xFF) / 255.0f;
	}
	return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
}

- (int)gutterSize
{
	// lazy initialization... 
	if (gutterSize == -1)
	{
		[self updateGutterSize];
	} 
	return gutterSize;
}

#pragma mark drawOperation-api

- (void)asyncDrawFinished: (NSImage*) bitmap 
{
	[[self drawLock] lock];
	[theImage release];
	theImage = [bitmap retain];
	[updater startRedrawInBackground];
	[[self drawLock] lock];
	
	pixelPerLine = [self bounds].size.height / [self getNumberOfLines];
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
