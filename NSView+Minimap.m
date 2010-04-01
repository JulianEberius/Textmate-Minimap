//
//  NSView+Minimap.m
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import "NSView+Minimap.h"
#import "MinimapView.h"
#import "TextMate.h"
#import "NSWindowController+Minimap.h"
#import "TextmateMinimap.h"

@interface NSView (Private_MM_NSView)
- (void)refreshMinimap;
- (MinimapView*)getMinimap;
- (void)scheduleRefresh;
@end


@implementation NSView (MM_NSView)

#pragma mark snapshot
/*
 Takes a snapshot of the complete TextView, returning NSBitmapImageRep
 */
- (NSBitmapImageRep *)snapshot
{
	[[[TextmateMinimap instance] theLock] lock];
		NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:[self bounds]];
		[self cacheDisplayInRect:[self bounds] toBitmapImageRep:imageRep];
	[[[TextmateMinimap instance] theLock] unlock];

	return imageRep;
}
/*
 Takes a snapshot of a part of the TextView, returning NSBitmapImageRep
 */
- (NSBitmapImageRep *) snapshotInRect:(NSRect)rect
{
	[[[TextmateMinimap instance] theLock] lock];
		NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:[self bounds]];
		[self cacheDisplayInRect:rect toBitmapImageRep:imageRep];
	[[[TextmateMinimap instance] theLock] unlock];

	return imageRep;
}
/*
 Takes a snapshot of the complete TextView, returning NSImage
 */
- (NSImage *)snapshotByDrawing
{
	[[[TextmateMinimap instance] theLock] lock];
		NSImage *snapshot = [[NSImage alloc] initWithSize:
							   [self bounds].size];
		[snapshot lockFocus];
		[self drawRect: [self frame]];
		[snapshot unlockFocus];
	[[[TextmateMinimap instance] theLock] unlock];

	return [snapshot autorelease];
}
/*
 Takes a snapshot of a part of the TextView, returning NSImage
 */
- (NSImage *)snapshotByDrawingInRect:(NSRect)rect
{
	[[[TextmateMinimap instance] theLock] lock];
	NSImage *snapshot = [[NSImage alloc] initWithSize:
						   rect.size];


	// recursively draw the subview and sub-subviews
	[snapshot lockFocus];
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform translateXBy:-rect.origin.x yBy:-rect.origin.y];
	[transform concat];
	[self drawRect:rect];
	[transform invert];
	[transform concat];
	[snapshot unlockFocus];

	// reset the transform to get back a clean graphic contexts for the rest of the drawing

	[[[TextmateMinimap instance] theLock] unlock];

	return [snapshot autorelease];
}

- (NSImage *)emptySnapshotImageFor:(MinimapView*)minimapView
{
	int gutterSize = [minimapView gutterSize];
	NSRect r = NSMakeRect(gutterSize, 0, [self bounds].size.width-gutterSize, [self bounds].size.height);
	NSRect bounds = [minimapView bounds];
	float scaleFactor = bounds.size.width / r.size.width;
	int h = r.size.height*scaleFactor;
	NSImage* image = [[NSImage alloc] initWithSize:NSMakeRect(0, 0, bounds.size.width, h).size];
	return [image autorelease];
}

#pragma mark minimap
/*
 Get this TextView's minimap
 */
- (MinimapView*) getMinimap
{
	NSWindowController* controller = [[self window] windowController];
	if ([controller isKindOfClass:OakProjectController] || [controller isKindOfClass:OakDocumentController]) {
		MinimapView* textShapeView = [controller getMinimapView];
		return textShapeView;
	}
	return nil;
}

/*
 Schedule a mimimap refresh in the near future... each subsequent call cancels the one before.
 Makes sense for typing events: not every keystroke triggers a refresh. Instead, a short time after the last keystroke
 the last scheduled refresh is carried out
 */
- (void)scheduleRefresh
{
	NSTimer* old_timer = [[TextmateMinimap instance] timer];
	if (old_timer != nil && [old_timer isValid]) {
		[old_timer invalidate];
	}
	// do not refresh instantly, wait for more typing..
	NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(refreshMinimap) userInfo:nil repeats:NO];
	[[TextmateMinimap instance ] setTimer:timer];
}

- (void)refreshMinimap
{
	[[self getMinimap] refreshDisplay];
}


#pragma mark other_swizzled_events
- (void)MM_selectTab:(id)sender
{
	[[[TextmateMinimap instance] theLock] lock];
	[[self getMinimap] setNewDocument];
	[self MM_selectTab:sender];
	[[[TextmateMinimap instance] theLock] unlock];
	[self refreshMinimap];
}

- (void)MM_mouseDown:(NSEvent *)theEvent
{
	[self MM_mouseUp:theEvent];
	// [self scheduleRefresh];
	[self refreshMinimap];
}

- (void)MM_mouseUp:(NSEvent *)theEvent
{
	[self MM_mouseUp:theEvent];
	// [self scheduleRefresh];
	[self refreshMinimap];
}

- (void)MM_keyUp:(NSEvent *)theEvent
{
	[self scheduleRefresh];
}

- (void)MM_toggleSoftWrap:(id)sender
{
	[self MM_toggleSoftWrap:sender];
	NSWindowController* wc = [[self window] windowController];
	if ([wc isKindOfClass:OakProjectController] || [wc isKindOfClass:OakDocumentController]) {
		int offset = [sender state] ? 56:40;
		NSDrawer* drawer = [wc getMinimapDrawer];
		MinimapView* mm = [wc getMinimapView];

		[drawer setTrailingOffset:offset];
		[mm refreshDisplay];
	}
}

- (void)MM_toggleShowSoftWrapInGutter:(id)sender
{
	[self MM_toggleShowSoftWrapInGutter:sender];
	[[self getMinimap] updateGutterSize];
}
- (void)MM_toggleLineNumbers:(id)sender
{
	[self MM_toggleLineNumbers:sender];
	[[self getMinimap] updateGutterSize];
}
- (void)MM_toggleShowBookmarksInGutter:(id)sender
{
	[self MM_toggleShowBookmarksInGutter:sender];
	[[self getMinimap] updateGutterSize];
}
- (void)MM_toggleFoldingsEnabled:(id)sender
{
	[self MM_toggleFoldingsEnabled:sender];
	[[self getMinimap] updateGutterSize];
}
- (void)MM_undo:(id)sender
{
	[self MM_undo:sender];
	[self scheduleRefresh];
}
- (void)MM_redo:(id)sender
{
	[self MM_redo:sender];
	[self scheduleRefresh];
}

@end
