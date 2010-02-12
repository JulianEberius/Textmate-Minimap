//
//  NSView+Screenshot.m
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import "NSView+Minimap.h"
#import "MinimapView.h"
#import "TextMate.h"
#import "TextmateMinimap.h"

@interface NSView (MM_NSView_Private)

- (void)refreshMinimap;
- (MinimapView*)getMinimap;
- (void)scheduleRefresh;

@end


@implementation NSView (MM_NSView)

#pragma mark drawing	

- (NSBitmapImageRep *)screenshot
{
	[[[self getMinimap] theLock] lock];	
	NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:[self bounds]];
	[self cacheDisplayInRect:[self bounds] toBitmapImageRep:imageRep];
	[[[self getMinimap] theLock] unlock];	
	return imageRep;
}

- (NSImage *)allocScreenshotByDrawing
{
	
	NSImage *screenshot = [[NSImage alloc] initWithSize:
						   [self bounds].size];
	[screenshot lockFocus];
	[self drawRect: [self frame]];
	[screenshot unlockFocus];
	return screenshot;
}

- (NSBitmapImageRep *) screenshotInRect:(NSRect)rect
{
	[[[self getMinimap] theLock] lock];	
	NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:rect];
	[self cacheDisplayInRect:rect toBitmapImageRep:imageRep];
	[[[self getMinimap] theLock] unlock];	
	return imageRep;
}

#pragma mark minimap
- (MinimapView*) getMinimap
{
	NSWindowController* controller = [[self window] windowController];
	if ([controller isKindOfClass:OakProjectController] || [controller isKindOfClass:OakDocumentController])
		for (NSDrawer *drawer in [[self window] drawers])
			if ([[drawer contentView] isKindOfClass:[MinimapView class]] )  {
				
				MinimapView* textShapeView = (MinimapView*)[drawer contentView];
				return textShapeView;
			}
	return nil;
}

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
	[[[self getMinimap] theLock] lock];	
	[self MM_selectTab:sender];
	[[[self getMinimap] theLock] unlock];	
	[self refreshMinimap];
}

- (void)MM_mouseUp:(NSEvent *)theEvent
{
	[self MM_mouseUp:theEvent];
	[self scheduleRefresh];
}

- (void)MM_keyUp:(NSEvent *)theEvent
{
	[self scheduleRefresh];
}

- (void)MM_toggleSoftWrap:(id)sender
{
	[self MM_toggleSoftWrap:sender];
	NSWindowController* wc = [[self window] windowController];
	if ([wc isKindOfClass:OakProjectController] || [wc isKindOfClass:OakDocumentController])
		for (NSDrawer *drawer in [[wc window] drawers])
			if ([[drawer contentView] isKindOfClass:[MinimapView class]] ) {
				[drawer setTrailingOffset:([sender state])?56:40];
				[(MinimapView*)[drawer contentView] refreshDisplay];
			}
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
