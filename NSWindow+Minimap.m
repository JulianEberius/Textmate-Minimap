//
//  NSWindow+Minimap.m
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import "NSWindow+Minimap.h"
#import "NSWindowController+Minimap.h"
#import "TextMate.h"
#import "TextMateMinimap.h"
#import "MinimapView.h"

@implementation NSWindow (MM_NSWindow)
/*
 Swizzled method: called when the user switches tabs (or load files)
 */
- (void)MM_setRepresentedFilename:(NSString*)aPath
{
	[self MM_setRepresentedFilename:aPath];
}

/*
 Swizzled method: called when a document change state (e.g. when saved to disk)
 */
- (void)MM_setDocumentEdited:(BOOL)flag
{
	[self MM_setDocumentEdited:flag];
	[[self windowController] refreshMinimap];
}
/*
 Swizzled method: called when a window is brought to the front
 - update the main menu to show the correct menu item ("show" or "hide" minimap)
 - update the lastWindowController
 */
- (void)MM_becomeMainWindow
{
	[self MM_becomeMainWindow];
	NSWindowController* controller = [self windowController];
	if ([controller isKindOfClass:OakProjectController] || [controller isKindOfClass:OakDocumentController])
		for (NSDrawer *drawer in [self drawers])
			if ([[drawer contentView] isKindOfClass:[MinimapView class]] )  {
				int state = [drawer state];
				if (state == NSDrawerClosedState || state == NSDrawerClosingState)
					[[TextmateMinimap instance] setMinimapMenuItem:NO];
				else 
					[[TextmateMinimap instance] setMinimapMenuItem:YES];
			}
	[[TextmateMinimap instance] setLastWindowController:controller];
}

@end
