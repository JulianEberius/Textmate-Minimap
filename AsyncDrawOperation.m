//
//  NewAsyncDrawOperation.m
//  Textmate-Minimap
//
//  Created by Julian Eberius on 19.03.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "AsyncDrawOperation.h"
#import "NSView+Minimap.h"

@interface NSView (TextMate_OakTextView_Only)
- (id)currentStyleSheet;
@end

@interface AsyncDrawOperation (Private_NewAsyncDrawOperation)
- (NSBitmapImageRep*)cropImageRep:(NSBitmapImageRep*)rep ToRect:(NSRect)rect;
- (void)initializeFillColorFromTextView;
- (void)makeCompleteSnapshot;
- (void)makePartialSnapshot;
- (void)partialBackgroundDraw;
- (BOOL)checkCancelled;
- (NSRect)scaleRect:(NSRect)rect withFactor:(float)factor;
@end

@implementation AsyncDrawOperation

- (id)initWithMinimapView:(MinimapView*)mv andMode:(int)md
{
	self = [super init];
    if (self) {
		minimapView = mv;
		mode = md;
		fillColor = nil;
	}
    return self;
}
- (id)initWithMinimapView:(MinimapView*)mv andMode:(int)md andUpdater:(BackgroundUpdater*)upd
{
	self = [self initWithMinimapView:mv andMode:md];
	if (self) {
		updater = upd;
	}
	return self;
}

- (void) dealloc
{
	[super dealloc];
//	[minimapView release];
}

- (void)setPartToDraw:(NSRect)part
{
	partToDraw = part;
}

- (void)main 
{
	if ([self isCancelled]) 
		return;
	
	switch (mode) {
		case MM_COMPLETE_IMAGE:
			[self makeCompleteSnapshot];
			break;
		case MM_PARTIAL_IMAGE:
			[self makePartialSnapshot];
			break;
		default:
			break;
	}
}

- (void)makePartialSnapshot 
{
	[[minimapView drawLock] lock];
	NSImage* old_image = [minimapView theImage];
	int gutterSize = [minimapView gutterSize];
	NSRect tvBounds = NSMakeRect(gutterSize, 0, 
								 [[minimapView textView] bounds].size.width-gutterSize, 
								 [[minimapView textView] bounds].size.height);
	NSRect bounds = [minimapView bounds];
	float scaleFactor = bounds.size.width / tvBounds.size.width;
	int h = tvBounds.size.height*scaleFactor;
	NSRect newImageRect = NSMakeRect(0, 0, bounds.size.width, h);
	NSImage* image = [[[NSImage alloc] initWithSize:newImageRect.size] autorelease];
	if ([self checkCancelled]) 
		return;
	NSRect rectToRedraw = NSMakeRect(tvBounds.origin.x, 
									 partToDraw.origin.y/scaleFactor, 
									 tvBounds.size.width,
									 partToDraw.size.height/scaleFactor);
	NSImage* drawnPart = [[minimapView textView] snapshotByDrawingInRect:rectToRedraw];
	if ([self checkCancelled]) 
		return;
	
	[image lockFocus];
		[fillColor set];
		NSRectFill(NSMakeRect(0, 0, [image size].width, [image size].height));
		// new image is longer or equal
		if (h >= [old_image size].height) {
			[old_image drawInRect:NSMakeRect(0, 0, [image size].width, [old_image size].height)
						 fromRect:NSZeroRect 
						operation:NSCompositeSourceOver fraction:1.0];
		}
		else {
			[old_image drawInRect:newImageRect
						 fromRect:NSMakeRect(0,0, [old_image size].width, [image size].height) 
						operation:NSCompositeSourceOver fraction:1.0];
		}
											
		[drawnPart drawInRect:partToDraw
					 fromRect:rectToRedraw 
					 operation:NSCompositeSourceOver fraction:1.0];
	[image unlockFocus];

	if ([self checkCancelled]) 
		return;
	[minimapView performSelectorOnMainThread:@selector(asyncDrawFinished:) withObject:image waitUntilDone:YES];

	[[minimapView drawLock] unlock];
}

<<<<<<< HEAD
=======
- (void)partialBackgroundDraw
{
	[[minimapView drawLock] lock];
	NSImage* image = [minimapView theImage];
	
	if ([self checkCancelled]) 
		return;
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
					 fromRect:rectToRedraw 
					operation:NSCompositeSourceOver fraction:1.0];
	[image unlockFocus];

	NSRect visRect = [minimapView getVisiblePartOfMinimap];
	int p1 = partToDraw.origin.y;
	int p2 = partToDraw.origin.y+partToDraw.size.height;
	int l1 = visRect.origin.y;
	int l2 = visRect.origin.y+visRect.size.height;
	if	((p1>=l1 && p1<=l2) || (p2>=l1 && p2 <= l2)) {
		[minimapView performSelectorOnMainThread:@selector(minorRefresh) withObject:NULL waitUntilDone:FALSE];

	}
	[[minimapView drawLock] unlock];
}

>>>>>>> newesttry
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

- (void)makeCompleteSnapshot
{
	[[minimapView drawLock] lock];
	if ([self checkCancelled]) 
		return;
	NSView* textView = [minimapView textView];
	NSBitmapImageRep* snapshot = [textView snapshot];
	int gutterSize = [minimapView gutterSize];
	NSBitmapImageRep* croppedSnapshot = [self cropImageRep:snapshot 
													ToRect:NSMakeRect(gutterSize, 0, [snapshot size].width-gutterSize, [snapshot size].height)];
	if ([self checkCancelled]) 
		return;
	NSRect bounds = [minimapView bounds];
	float scaleFactor = bounds.size.width / [croppedSnapshot size].width;
	int h = croppedSnapshot.size.height*scaleFactor;
	
	NSImage* image = [[[NSImage alloc] initWithSize:NSMakeRect(0, 0, bounds.size.width, h).size] autorelease];
	
	if ([self checkCancelled]) 
		return;
	[self initializeFillColorFromTextView];

	
	[image setFlipped:YES];
	[image lockFocus];
		NSRect imgRect = NSMakeRect(0, 0, bounds.size.width, h);
		[croppedSnapshot drawInRect:imgRect];
	[image unlockFocus];
	[image setFlipped:NO];
	
	if ([self checkCancelled]) 
		return;
	[minimapView performSelectorOnMainThread:@selector(asyncDrawFinished:) withObject:image waitUntilDone:YES];
	[[minimapView drawLock] unlock];
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
