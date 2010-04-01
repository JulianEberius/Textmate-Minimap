//
//  NSScrollView+Minimap.m
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import "NSScrollView+Minimap.h"
#import "TextMate.h"
#import "NSWindowController+Minimap.h"
#import "MinimapView.h"

@implementation NSScrollView (MM_NSScrollView) 

/*
 Swizzled method: while scrolling, do "small refresh" of the minimap (redraw only the "viewableRange" not the complete image)
 */
- (void) MM_reflectScrolledClipView:(NSClipView*)clipView
{
	[self MM_reflectScrolledClipView:clipView];
	
	NSWindowController* controller = [[self window] windowController];
	if ([controller isKindOfClass:OakProjectController] || [controller isKindOfClass:OakDocumentController]) {
		MinimapView* textShapeView = [controller getMinimapView];
		[textShapeView refreshViewableRange];
	}
	 
}

@end
