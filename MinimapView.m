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

@interface DrawOperation : NSOperation
{	
	MinimapView* minimapView;
}

- (id)initWithMinimapView:(MinimapView*)mv;

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
	NSView* textView = [minimapView textView];
	NSBitmapImageRep* screenshot = [textView screenshot];
	
	NSColor* refColor = [[screenshot colorAtX:0 y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	int i = 1;
	NSColor* color = [[screenshot colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	while ([color isEqual:refColor]) {
		i++;
		color = [[screenshot colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	}
	
	if ([self isCancelled]) 
		return;

	NSBitmapImageRep* croppedScreenshot = [self cropImageRep:screenshot ToRect:NSMakeRect(i+1, 0, [screenshot size].width-(i+1), [screenshot size].height)];
		
	if ([self isCancelled]) 
		return;

	NSImage* image = [[[NSImage alloc] initWithSize:bounds.size] autorelease];
	[image setFlipped:YES];

	[image lockFocus];
		NSRect rectToDrawTo = bounds;
		float numLines = [minimapView getNumberOfLines];

		int _pixelPerLine = bounds.size.height / numLines;
		if (_pixelPerLine > 6) {
			float newHeight = 6*numLines;
			rectToDrawTo.size.height = newHeight;		
			rectToDrawTo.origin.y = bounds.size.height-newHeight;
		}
		[croppedScreenshot drawInRect:rectToDrawTo];
	[image unlockFocus];
	
	if ([self isCancelled] || image == nil)
		return;

	[minimapView performSelectorOnMainThread:@selector(drawFinished:) withObject:image  waitUntilDone:FALSE];
}

@end

@interface NSView (MM_NSView_OnlyByOakTextView)

- (unsigned int)lineHeight;

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
		// for snow leopard
		//[self gcdDraw];
		_refreshAll = FALSE;
	}
	[_nextImage drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];

	// drawing the vis rect
	[self updateViewableRange];
	NSRect visibleHighlightRect = NSMakeRect(0,
											 _viewableRange.location*_pixelPerLine,
											 rect.size.width-1,
											 _viewableRange.length*_pixelPerLine);

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
	
	// find out, whether a vertical scroller is displayed... strangely, [sv hasVeticalScroller] always returns YES 
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
		_pixelPerLine = 6;
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

		unsigned int lineIdx = floor(mouseLoc.y / _pixelPerLine);
		
        switch ([theEvent type]) {
            case NSLeftMouseDragged:
				[windowController scrollToLine:lineIdx];
				break;
            case NSLeftMouseUp:
				if (isInside){
					[windowController scrollToLine:lineIdx];
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

- (int) getNumberOfLines
{
	unsigned int lineHeight = [_textView lineHeight];
	
	float h = [_textView bounds].size.height;
	int totalLines = round(h/lineHeight);
	
	return totalLines;
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//FOR SNOW LEOPARD
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
- (NSBitmapImageRep*)cropImageRep:(NSBitmapImageRep*)rep ToRect:(NSRect)rect {
	CGImageRef cgImg = CGImageCreateWithImageInRect([rep CGImage], NSRectToCGRect(rect)); NSBitmapImageRep *result = [[NSBitmapImageRep alloc] initWithCGImage:cgImg];
	
	CGImageRelease(cgImg);          
	return [result autorelease];
}       

- (void)gcdDraw {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
		
		NSRect bounds = [self bounds];
		NSBitmapImageRep* screenshot = [_textView screenshot];
		
		NSColor* refColor = [[screenshot colorAtX:0 y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
		int i = 1;
		NSColor* color = [[screenshot colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
		while ([color isEqual:refColor]) {
			i++;
			color = [[screenshot colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
		}
		
		NSBitmapImageRep* croppedScreenshot = [self cropImageRep:screenshot ToRect:NSMakeRect(i+1, 0, [screenshot size].width-(i+1), [screenshot size].height)];
		
		NSImage* image = [[[NSImage alloc] initWithSize:bounds.size] autorelease];
		[image setFlipped:YES];
		[image lockFocus];
		NSRect rectToDrawTo = bounds;
		float numLines = [self getNumberOfLines];
		
		_pixelPerLine = bounds.size.height / numLines;
		if (_pixelPerLine > 6) {
			float newHeight = 6*numLines;
			rectToDrawTo.size.height = newHeight;		
			rectToDrawTo.origin.y = bounds.size.height-newHeight;
		}
		[croppedScreenshot drawInRect:rectToDrawTo];
		
		[image unlockFocus];
		
        dispatch_async(dispatch_get_main_queue(), ^{
            [self drawFinished:image];
        });
    });
	
}

*/


@end
