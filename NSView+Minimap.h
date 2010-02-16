//
//  NSView+Minimap.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSView (MM_NSView)

- (NSBitmapImageRep *) snapshot;
- (NSBitmapImageRep *) snapshotInRect:(NSRect)rect;

- (NSImage *)snapshotByDrawing;
- (NSImage *)snapshotByDrawingInRect:(NSRect)rect;

- (void)MM_selectTab:(id)sender;
- (void)MM_keyUp:(NSEvent *)theEvent;
- (void)MM_mouseUp:(NSEvent *)theEvent;
- (void)MM_undo:(id)sender;
- (void)MM_redo:(id)sender;

- (void)MM_toggleSoftWrap:(id)sender;

@end
