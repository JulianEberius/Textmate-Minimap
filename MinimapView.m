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
- (NSImage*)doDrawRect:(NSRect)rect withImage:(NSImage*)image;
- (int)getGutterSize:(NSImage *)screenshot;
- (void) updateViewableRange;
- (int)getNumberOfLines;
- (void)drawFinished:(NSImage*) bitmap;
@end

@interface DrawOperation : NSOperation
{	
	MinimapView *minimapView;
	NSImage* image;
	NSRect rect;
}

- (id)initWithMinimapView:(MinimapView*)mv andRect:(NSRect) rect andImage:(NSImage*)image;

@end

@implementation DrawOperation

- (id)initWithMinimapView:(MinimapView*)mv andRect:(NSRect)r andImage:(NSImage*)img
{
    if (![super init]) return nil;
    minimapView = [mv retain];
	rect = r;
	image = [img retain];
    return self;
}

- (void)dealloc {
    [minimapView release], minimapView = nil;
	[image release], image = nil;
    [super dealloc];
}

- (void)main {
	if (![self isCancelled]) 
	{
		NSImage* bitmap;
		bitmap = [minimapView doDrawRect:rect withImage:image];
		if (![self isCancelled] && bitmap != nil)
		{
			[minimapView performSelectorOnMainThread:@selector(drawFinished:) withObject:bitmap waitUntilDone:FALSE];
		}
		else {
			//NSLog(@"got cancelled 1");
		}
	} else {
		//NSLog(@"got cancelled 2");
	}
}

@end

@interface NSView (MM_NSView_OnlyByOakTextView)

- (unsigned int)lineHeight;

@end



@implementation MinimapView

@synthesize windowController;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		_queue = [[NSOperationQueue alloc] init];
		[_queue setMaxConcurrentOperationCount:1];
		_refreshViewableRange = FALSE;
		_refreshAll = TRUE;
		_needsNewImage = FALSE;
	}
    return self;
}

- (void) viewDidEndLiveResize
{
	_pixelPerLine = [self bounds].size.height / [self getNumberOfLines];
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

- (BOOL)needsNewImage
{
	return _needsNewImage;
}

- (void)drawRect:(NSRect)rect
{	
	NSLog(@"drawing...");
	if (![self inLiveResize] && _refreshAll) 
	{
		_needsNewImage = YES;
		[_textView setNeedsDisplay:YES];
	}
	NSRect rectToDrawTo = [self bounds];
	BOOL fillWithBlack = NO;
	_pixelPerLine = [self bounds].size.height / [self getNumberOfLines];
	if (_pixelPerLine > 6) {
		float newHeight = 6*[self getNumberOfLines];
		rectToDrawTo.size.height = newHeight;		
		fillWithBlack = YES;
		_pixelPerLine = 6;	
	}
	[self updateViewableRange];
	
	[_nextImage drawInRect:rectToDrawTo fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	if (fillWithBlack)
		NSRectFill(NSMakeRect(rectToDrawTo.origin.x,
							  rectToDrawTo.origin.y+rectToDrawTo.size.height, 
							  rectToDrawTo.size.width, [self bounds].size.height-rectToDrawTo.size.height));

	
	NSRect visibleHighlightRect = NSMakeRect(0,
											 _viewableRange.location*_pixelPerLine,
											 rect.size.width-1,
											 _viewableRange.length*_pixelPerLine);
	[NSGraphicsContext saveGraphicsState];
	[[NSColor colorWithCalibratedRed:0.549 green:0.756 blue:1 alpha:0.7] set];
	[NSBezierPath setDefaultLineWidth:1];
	[NSBezierPath strokeRect:visibleHighlightRect];
	[NSGraphicsContext restoreGraphicsState];
	_refreshAll = FALSE;
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
	
	[self setNeedsDisplay:YES];
}

- (void)setMinimapImage:(NSImage *)image
{
	_needsNewImage = NO;
	DrawOperation* op = [[DrawOperation alloc] initWithMinimapView:self andRect:[self bounds] andImage:image];
	[_queue cancelAllOperations];
	[_queue addOperation:op];
	[op release];
	[image release];
}

- (NSImage*)doDrawRect:(NSRect) rect withImage:(NSImage*) screenshot
{
	NSImage* bitmap = [[NSImage alloc] initWithSize: rect.size];
	
	[bitmap lockFocus];
	
		[screenshot drawInRect:rect
					  fromRect:NSMakeRect([self getGutterSize:screenshot], 0, [screenshot size].width, [screenshot size].height) 
					 operation:NSCompositeCopy 
					  fraction:1.0];
	[bitmap unlockFocus];
	[bitmap autorelease];
	return bitmap;
}

- (int)getGutterSize:(NSImage*)screenshot
{
	int w = [screenshot size].width;
	NSImage* firstLine = [[NSImage alloc] initWithSize: NSMakeSize(w, 1)];
	[firstLine lockFocus];
	[screenshot drawInRect:NSMakeRect(0, 0, w, 1) 
				  fromRect:NSMakeRect(0, 0, w, 1) 
				 operation:NSCompositeCopy fraction:1.0];
	[firstLine unlockFocus];
				
	NSBitmapImageRep* raw_img = [NSBitmapImageRep imageRepWithData:[firstLine TIFFRepresentation]];
	[firstLine release];
	NSColor* refColor = [[raw_img colorAtX:0 y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	int i = 1;
	NSColor* color = [[raw_img colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	while ([color isEqual:refColor]) {
		i++;
		color = [[raw_img colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	}
	return i+1;
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

- (void)setNeedsNewImage:(BOOL)flag
{
	_needsNewImage = flag;
}

- (int) getNumberOfLines
{
	unsigned int lineHeight = [_textView lineHeight];
	
	float h = [_textView bounds].size.height;
	int totalLines = round(h/lineHeight);
	
	return totalLines;
}
@end
