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
- (BOOL)minimapNeedsNewImage;
- (void)setMinimapImage:(NSImage*)image;
- (MinimapView*)getMinimap;
- (void)scheduleRefresh;

@end


@implementation NSView (MM_NSView)

#pragma mark drawing
- (NSImage *)allocScreenshotByDrawing {
	NSImage *screenshot = [[NSImage alloc] initWithSize: 
							[self bounds].size];
	[screenshot lockFocus];
		[self MM_drawRect: [self frame]];
	[screenshot unlockFocus];
	return screenshot;
}

- (void)MM_drawRect:(NSRect)rect
{
	[self MM_drawRect:rect];
	
	if ([self minimapNeedsNewImage]) 
	{
		NSLog(@"there is need");
		NSImage* image = [self allocScreenshotByDrawing];
		[self setMinimapImage:image];
	}
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

- (void)setMinimapNeedsNoImage
{
	[[self getMinimap] setNeedsNewImage:NO];
}

- (BOOL)minimapNeedsNewImage
{
	return [[self getMinimap] needsNewImage];
}

- (void)setMinimapImage:(NSImage*)image
{
	[[self getMinimap] setMinimapImage:image];
}

#pragma mark other_swizzled_events

- (void)MM_selectTab:(id)sender
{
	[self MM_selectTab:sender];
}

- (void)MM_mouseUp:(NSEvent *)theEvent
{
	[self MM_mouseUp:theEvent];
	[self scheduleRefresh];
}

- (void)MM_mouseDragged:(NSEvent *)theEvent
{
	[self MM_mouseDragged:theEvent];
	//[self refreshMinimap];
}

- (void)MM_keyUp:(NSEvent *)theEvent
{
	[self scheduleRefresh];
}

- (void)MM_undo:(id)sender
{
	[self MM_undo:sender];
	[self scheduleRefresh];
}
- (void)MM_redo:(id)sender
{
	[self MM_redo:sender];
	[self scheduleRefresh];}


@end
