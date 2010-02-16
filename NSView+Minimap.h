//
//  NSView+Minimap.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSView (MM_NSView)

#pragma mark snapshot
- (NSBitmapImageRep *) snapshot;
- (NSBitmapImageRep *) snapshotInRect:(NSRect)rect;
- (NSImage *)snapshotByDrawing;
- (NSImage *)snapshotByDrawingInRect:(NSRect)rect;

#pragma mark other_swizzled_events
- (void)MM_selectTab:(id)sender;
- (void)MM_keyUp:(NSEvent *)theEvent;
- (void)MM_mouseUp:(NSEvent *)theEvent;
- (void)MM_undo:(id)sender;
- (void)MM_redo:(id)sender;

- (void)MM_toggleSoftWrap:(id)sender;
- (void)MM_toggleShowSoftWrapInGutter:(id)sender;
- (void)MM_toggleLineNumbers:(id)sender;
- (void)MM_toggleShowBookmarksInGutter:(id)sender;
- (void)MM_toggleFoldingsEnabled:(id)sender;

@end
