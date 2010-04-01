//
//  NewAsyncDrawOperation.m
//  Textmate-Minimap
//
//  Created by Julian Eberius on 19.03.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "AsyncBGDrawOperation.h"
#import "NSView+Minimap.h"

@interface NSView (TextMate_OakTextView_Only)
- (id)currentStyleSheet;
@end

@interface AsyncBGDrawOperation (Private_NewAsyncDrawOperation)
- (NSBitmapImageRep*)cropImageRep:(NSBitmapImageRep*)rep ToRect:(NSRect)rect;
- (void)initializeFillColorFromTextView;
- (void)makeCompleteSnapshot;
- (void)makePartialSnapshot;
- (void)partialBackgroundDraw;
- (BOOL)checkCancelled;
- (NSRect)scaleRect:(NSRect)rect withFactor:(float)factor;
@end

@implementation AsyncBGDrawOperation

- (id)initWithMinimapView:(MinimapView*)mv andUpdater:(BackgroundUpdater*)upd
{
	self = [super init];
	if (self) {
		minimapView = mv;
		fillColor = nil;
		rangeObject = nil;
		updater = upd;
	}
	return self;
}

- (void) dealloc
{
	[super dealloc];
}

- (void)setPartToDraw:(NSRect)part andRangeObject:(NSValue*)range
{
	partToDraw = part;
	rangeObject = range;
}
- (void)main
{
	if ([self isCancelled])
		return;
	[self partialBackgroundDraw];
}

- (void)partialBackgroundDraw
{
	[[minimapView drawLock] lock];
	if ([self checkCancelled])
		return;
	NSImage* image = [minimapView theImage];

	NSRect tvBounds = [[minimapView textView] bounds];
	int gutterSize = [minimapView gutterSize];
	float scaleFactor = tvBounds.size.height / [image size].height;
	NSRect rectToRedraw = NSMakeRect(gutterSize,
									 partToDraw.origin.y*scaleFactor,
									 tvBounds.size.width - gutterSize,
									 partToDraw.size.height*scaleFactor);
	NSImage* drawnPart = [[minimapView textView] snapshotByDrawingInRect:rectToRedraw];

	if ([self checkCancelled])
		return;

	[image lockFocus];
	[drawnPart drawInRect:partToDraw
				 fromRect:NSZeroRect
				operation:NSCompositeSourceOver fraction:1.0];
	[image unlockFocus];

	if ([self checkCancelled])
		return;
	NSRect visRect = [minimapView getVisiblePartOfMinimap];
	int p1 = partToDraw.origin.y;
	int p2 = partToDraw.origin.y+partToDraw.size.height;
	int l1 = visRect.origin.y;
	int l2 = visRect.origin.y+visRect.size.height;
	if	((p1>=l1 && p1<=l2) || (p2>=l1 && p2 <= l2)) {
		[minimapView performSelectorOnMainThread:@selector(smallRefresh) withObject:NULL waitUntilDone:NO];
	}
	if ([self checkCancelled])
		return;
	[updater performSelectorOnMainThread:@selector(rangeWasRedrawn:) withObject:rangeObject waitUntilDone:YES];

	[[minimapView drawLock] unlock];
}

- (BOOL)checkCancelled
{
	if ([self isCancelled]) {
		[[minimapView drawLock] unlock];
		return YES;
	}
	return NO;
}

- (NSRect)scaleRect:(NSRect)rect withFactor:(float)factor
{
	return NSMakeRect(rect.origin.x*factor, rect.origin.y*factor, rect.size.width*factor, rect.size.height*factor);
}
/*
 Copy&Pasted from the interwebs for cropping NSBitmapImageReps (used for cropping the gutter from the TextView Snapshots)
 */
- (NSBitmapImageRep*)cropImageRep:(NSBitmapImageRep*)rep ToRect:(NSRect)rect {
	CGImageRef cgImg = CGImageCreateWithImageInRect([rep CGImage], NSRectToCGRect(rect)); NSBitmapImageRep *result = [[NSBitmapImageRep alloc] initWithCGImage:cgImg];

	CGImageRelease(cgImg);
	return [result autorelease];
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
