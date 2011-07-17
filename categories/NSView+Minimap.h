
//
//  NSView+Minimap.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MinimapView;

@interface NSView (MM_NSView)

#pragma mark snapshot
- (NSBitmapImageRep*) snapshot;
- (NSBitmapImageRep*) snapshotInRect:(NSRect)rect;
- (NSImage*)snapshotByDrawing;
- (NSImage*)snapshotByDrawingInRect:(NSRect)rect;
- (NSImage*)emptySnapshotImageFor:(MinimapView*)minimapView;

#pragma mark other_swizzled_events
- (void)MM_selectTab:(id)sender;
- (void)MM_keyDown:(NSEvent *)theEvent;
- (void)MM_mouseDown:(NSEvent *)theEvent;
- (void)MM_mouseUp:(NSEvent *)theEvent;
- (void)MM_undo:(id)sender;
- (void)MM_redo:(id)sender;
- (void)MM_performKeyEquivalent:(id)event;
- (void)MM_toggleSoftWrap:(id)sender;
- (void)MM_toggleShowSoftWrapInGutter:(id)sender;
- (void)MM_toggleLineNumbers:(id)sender;
- (void)MM_toggleShowBookmarksInGutter:(id)sender;
- (void)MM_toggleFoldingsEnabled:(id)sender;
- (void)MM_dealloc;
@end
