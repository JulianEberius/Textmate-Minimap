//
//  AsyncDrawOperation.mm
//
//  Created by Julian Eberius on 2010-02-16.
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

#import "AsyncDrawOperation.h"
#import "NSView+Minimap.h"

@interface NSView (TextMate_OakTextView_Only)
- (id)currentStyleSheet;
@end


@interface AsyncDrawOperation (Private_AsyncDrawOperation)
- (void)fullDraw;
- (void)partialDraw;
- (int)getGutterSize;
- (NSBitmapImageRep*)cropImageRep:(NSBitmapImageRep*)rep ToRect:(NSRect)rect;
- (void)initializeFillColorFromTextView;
@end

@implementation AsyncDrawOperation

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

/*
 decide which of the three drawing modes has to be used:
 - Draw Mode A: scaling the picture down, if there the lines in the minimap would get to big (aka "look stupid")
 - Draw Mode B: draw only a part of the textview if the lines in the minimap would get to small (and performance would be horrible :-) )
 - Draw Mode C: draw the complete textView into the minimap as it is (aka "looks cool and is usable")
 */
- (void)main {
	if ([self isCancelled]) 
		return;

	bounds = [minimapView bounds];
	rectToDrawTo = bounds;
	numLines = [minimapView getNumberOfLines];
	float pixelPerLine = bounds.size.height / numLines;
	float scaleUpThreshold = [[NSUserDefaults standardUserDefaults] floatForKey:@"Minimap_scaleUpThreshold"];
	
	if (pixelPerLine > scaleDownThreshold) {
		float newHeight = scaleDownTo*numLines;
		rectToDrawTo.size.height = newHeight;		
		rectToDrawTo.origin.y = bounds.size.height-newHeight;
		
		[self initializeFillColorFromTextView];
		[minimapView setMinimapLinesStart:0];
		[minimapView setViewableRangeScaling:1.0];
		[self fullDraw];
	} 
	else if (pixelPerLine < scaleUpThreshold)
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
/*
 Draw the complete TextView into the minimap, using rectToDrawTo to realize "Draw Mode A" (for very small texts)
 or just doing Draw Mode C when everything is fine
 */
- (void) fullDraw
{
	NSView* textView = [minimapView textView];
	NSBitmapImageRep* snapshot = [textView snapshot];
	
	if ([self isCancelled]) 
		return;
		
	int gutterSize = [self getGutterSize];
	NSBitmapImageRep* croppedSnapshot = [self cropImageRep:snapshot 
											ToRect:NSMakeRect(gutterSize, 0, [snapshot size].width-gutterSize, [snapshot size].height)];
		
	if ([self isCancelled]) 
		return;

	NSImage* image = [[[NSImage alloc] initWithSize:bounds.size] autorelease];
	[image setFlipped:YES];

	[image lockFocus];
		// fill the rest of the minimap if necessary
		if (rectToDrawTo.size.height != bounds.size.height)
		{
			[fillColor set];
			NSRectFill(bounds);
		}
		[croppedSnapshot drawInRect:rectToDrawTo];
	[image unlockFocus];
	
	if ([self isCancelled] || image == nil)
		return;

	[minimapView performSelectorOnMainThread:@selector(asyncDrawFinished:) withObject:image  waitUntilDone:FALSE];
}
/*
 Implements drawing mode B: draw only a part of the minimap
 a bit more complicated...
 */
- (void) partialDraw
{
	NSView* textView = [minimapView textView];
	NSRect tvBounds = [textView bounds];
	int scaleUpTo = [[NSUserDefaults standardUserDefaults] integerForKey:@"Minimap_scaleUpTo"];
	float visiblePercentage = bounds.size.height / (numLines*scaleUpTo);
	[minimapView setViewableRangeScaling:(1/visiblePercentage)];
	
	NSScrollView* sv = (NSScrollView*)[[textView superview] superview];
	float percentage = [[sv verticalScroller] floatValue];
	
	float middle = percentage*(tvBounds.size.height-[textView visibleRect].size.height) + [textView visibleRect].size.height/2;
	float mysteriousHeight = (visiblePercentage * tvBounds.size.height) - [textView visibleRect].size.height;
	float begin = middle - (percentage*mysteriousHeight) - ([textView visibleRect].size.height/2);
	
	int gutterSize = [self getGutterSize];
	NSRect rectToSnapshot = NSMakeRect( gutterSize,
										begin,
										tvBounds.size.width-gutterSize,
										visiblePercentage * tvBounds.size.height);
	[minimapView setMinimapLinesStart:((begin/tvBounds.size.height)*numLines)];

	NSImage* snapshot = [textView snapshotByDrawingInRect:rectToSnapshot];
	
	NSImage* image = [[[NSImage alloc] initWithSize:bounds.size] autorelease];

	[image lockFocus];
		[snapshot drawInRect:rectToDrawTo fromRect:rectToSnapshot operation:NSCompositeCopy fraction:1.0];
	[image unlockFocus];
	
	[minimapView performSelectorOnMainThread:@selector(asyncDrawFinished:) withObject:image  waitUntilDone:FALSE];
}

/*
 Copy&Pasted from the interwebs for cropping NSBitmapImageReps (used for cropping the gutter from the TextView Snapshots)
 */
- (NSBitmapImageRep*)cropImageRep:(NSBitmapImageRep*)rep ToRect:(NSRect)rect {
	CGImageRef cgImg = CGImageCreateWithImageInRect([rep CGImage], NSRectToCGRect(rect)); NSBitmapImageRep *result = [[NSBitmapImageRep alloc] initWithCGImage:cgImg];
	
	CGImageRelease(cgImg);          
	return [result autorelease];
}

/*
 Get the size of the gutter in pixel from the minimap.
 */
- (int)getGutterSize
{
	int gutterSize = [minimapView gutterSize];
	// lazy initialization... 
	if (gutterSize == -1)
	{
		[minimapView updateGutterSize];
		gutterSize = [minimapView gutterSize];
	}
	return gutterSize;
}

- (void)initializeFillColorFromTextView
{
	id stylesheet = [[minimapView textView] currentStyleSheet];
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
	fillColor = [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
}

@end
