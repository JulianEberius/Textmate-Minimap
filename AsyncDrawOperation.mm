//
//  AsyncDrawOperation.mm
//
//  Created by Julian Eberius on 2010-02-16.
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

#import "AsyncDrawOperation.h"
#import "NSView+Minimap.h"

@interface AsyncDrawOperation (Private_AsyncDrawOperation)
- (void)fullDraw;
- (void)partialDraw;
- (int)getGutterSize;
- (NSBitmapImageRep*)cropImageRep:(NSBitmapImageRep*)rep ToRect:(NSRect)rect;
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

- (void)main {
	if ([self isCancelled]) 
		return;

	bounds = [minimapView bounds];
	rectToDrawTo = bounds;
	numLines = [minimapView getNumberOfLines];
	pixelPerLine = bounds.size.height / numLines;
	
	if (pixelPerLine > scaleDownThreshold) {
		float newHeight = scaleDownTo*numLines;
		rectToDrawTo.size.height = newHeight;		
		rectToDrawTo.origin.y = bounds.size.height-newHeight;
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
		[croppedSnapshot drawInRect:rectToDrawTo];
	[image unlockFocus];
	
	if ([self isCancelled] || image == nil)
		return;

	[minimapView performSelectorOnMainThread:@selector(asyncDrawFinished:) withObject:image  waitUntilDone:FALSE];
}

- (void) partialDraw
{
	NSView* textView = [minimapView textView];
	NSRect tvBounds = [textView bounds];
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
										tvBounds.size.width,
										visiblePercentage * tvBounds.size.height);
	[minimapView setMinimapLinesStart:((begin/tvBounds.size.height)*numLines)];

	NSImage* snapshot = [textView snapshotByDrawingInRect:rectToSnapshot];
	
	NSImage* image = [[[NSImage alloc] initWithSize:bounds.size] autorelease];

	[image lockFocus];
		[snapshot drawInRect:rectToDrawTo fromRect:rectToSnapshot operation:NSCompositeCopy fraction:1.0];
	[image unlockFocus];
	
	[minimapView performSelectorOnMainThread:@selector(asyncDrawFinished:) withObject:image  waitUntilDone:FALSE];
}

- (NSBitmapImageRep*)cropImageRep:(NSBitmapImageRep*)rep ToRect:(NSRect)rect {
	CGImageRef cgImg = CGImageCreateWithImageInRect([rep CGImage], NSRectToCGRect(rect)); NSBitmapImageRep *result = [[NSBitmapImageRep alloc] initWithCGImage:cgImg];
	
	CGImageRelease(cgImg);          
	return [result autorelease];
}

- (int)getGutterSize
{
	int gutterSize = [minimapView gutterSize];
	if (gutterSize == -1)
	{
		[minimapView updateGutterSize];
		gutterSize = [minimapView gutterSize];
	}
	return gutterSize;
}

@end
