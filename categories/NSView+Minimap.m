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
- (void)setDirtyAndRefreshMinimap;
- (void)setDirtyIfMovedAndRefreshMinimap;
- (MinimapView*)getMinimap;
- (void)schedule:(SEL)selector;
- (void)saveValue:(id)value toIvar:(NSString*)key;
- (id)getIVar:(NSString*)key;
- (float)getScrollbarValue;
@end


@implementation NSView (MM_NSView)

#pragma mark snapshot
/*
 Takes a snapshot of the complete TextView, returning NSBitmapImageRep
 */
- (NSRect) croppedBounds
{
    BOOL cropHorizontaly = [[NSUserDefaults standardUserDefaults] boolForKey:@"Minimap_cropMinimapHorizontaly"];
    NSRect croppedBounds = [self bounds];
    if (cropHorizontaly) {
        croppedBounds.size.width = [self visibleRect].size.width;
    }
    return croppedBounds;
}

- (NSBitmapImageRep *)snapshot
{
    NSRect croppedBounds = [self croppedBounds];
    [[[TextmateMinimap instance] theLock] lock];
    NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:croppedBounds];
    [self cacheDisplayInRect:croppedBounds toBitmapImageRep:imageRep];
    [[[TextmateMinimap instance] theLock] unlock];
    
    return imageRep;
}
/*
 Takes a snapshot of a part of the TextView, returning NSBitmapImageRep
 */
- (NSBitmapImageRep *) snapshotInRect:(NSRect)rect
{
    NSRect croppedBounds = [self croppedBounds];
    [[[TextmateMinimap instance] theLock] lock];
    NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:croppedBounds];
    [self cacheDisplayInRect:rect toBitmapImageRep:imageRep];
    [[[TextmateMinimap instance] theLock] unlock];
    
    return imageRep;
}
/*
 Takes a snapshot of the complete TextView, returning NSImage
 */
- (NSImage *)snapshotByDrawing
{
    NSRect croppedBounds = [self croppedBounds];
    [[[TextmateMinimap instance] theLock] lock];
    NSImage *snapshot = [[NSImage alloc] initWithSize:
                         croppedBounds.size];
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
    NSRect croppedBounds = [self bounds];
    int gutterSize = [minimapView gutterSize];
    NSRect r = NSMakeRect(gutterSize, 0, croppedBounds.size.width-gutterSize, croppedBounds.size.height);
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
        MinimapView* minimapView = [controller getMinimapView];
        return minimapView;
    }
    return nil;
}

/*
 Schedule a mimimap refresh in the near future... each subsequent call cancels the one before.
 Makes sense for typing events: not every keystroke triggers a refresh. Instead, a short time after the last keystroke
 the last scheduled refresh is carried out
 */
- (void)schedule:(SEL)selec
{
    NSTimer* old_timer = [[TextmateMinimap instance] timer];
    if (old_timer != nil && [old_timer isValid]) {
        [old_timer invalidate];
    }
    // do not refresh instantly, wait for more typing..
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:selec userInfo:nil repeats:NO];
    [[TextmateMinimap instance ] setTimer:timer];
}

- (void)refreshMinimap
{
    [[self getMinimap] refresh];
}

- (void)setDirtyAndRefreshMinimap
{
    MinimapView* minimap = [self getMinimap];
    [minimap setDirty:YES];
    [minimap refresh];
}

- (void)setDirtyIfMovedAndRefreshMinimap
{
    MinimapView* minimap = [self getMinimap];
    if ([(NSNumber*)[self getIVar:@"numLines_changed"] boolValue]) {
        [minimap setDirty:YES];
        [self saveValue:[NSNumber numberWithBool:NO] toIvar:@"numLines_changed"];
    }
    [minimap refresh];
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
    [self MM_mouseDown:theEvent];
    [self saveValue:[NSNumber numberWithFloat:[self getScrollbarValue]] toIvar:@"scrollbar_pos"];
}

- (void)MM_mouseUp:(NSEvent *)theEvent
{
    [self MM_mouseUp:theEvent];
    
    // we update the complete minimap if the scrollbar moved during an operation
    // that's basically a guess though ("if the slceen moved, there was a big update")
    // mainly, it prevents complete redraws on simple clicks...
    float scrollbarPos = [self getScrollbarValue];
    if (scrollbarPos != [(NSNumber*)[self getIVar:@"scrollbar_pos"] floatValue])
        [[self getMinimap] setDirty:YES];
    
    [self refreshMinimap];
}

- (void)MM_keyDown:(NSEvent *)theEvent
{
    MinimapView* minimap = [self getMinimap];
    int old_value = [minimap numberOfLines];
    [self MM_keyDown:theEvent];
    if (old_value != [minimap numberOfLines]) {
        [self saveValue:[NSNumber numberWithBool:YES] toIvar:@"numLines_changed"];
    }
    
    [self schedule:@selector(setDirtyIfMovedAndRefreshMinimap)];
}

- (void)MM_toggleSoftWrap:(id)sender
{
    [self MM_toggleSoftWrap:sender];
    NSWindowController* wc = [[self window] windowController];
    if ([wc isInSidepaneMode]
        && [wc isKindOfClass:OakProjectController] || [wc isKindOfClass:OakDocumentController]) {
        int offset = [sender state] ? 56:40;
        NSDrawer* drawer = [wc getMinimapDrawer];
        MinimapView* mm = [wc getMinimapView];
        
        [drawer setTrailingOffset:offset];
        [mm refresh];
        // do a complete redraw if the softWrapping was changed
        //[mm firstRefresh];
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
    [self schedule:@selector(refreshMinimap)];
}
- (void)MM_redo:(id)sender
{
    [self MM_redo:sender];
    [self schedule:@selector(refreshMinimap)];
}

- (void)MM_toggleCurrentBookmark:(id)arg1 
{
    [self MM_toggleCurrentBookmark:arg1];
    
    NSMutableArray* bookmarks = [[self getMinimap] bookmarks];
    int currentLine = [[[self window] windowController] getCurrentLine:self];
    
    unsigned idx = [bookmarks indexOfObject:[NSNumber numberWithInteger:currentLine]];
    if (idx != NSNotFound) {
        [bookmarks removeObjectAtIndex:idx];
    } else {
        [bookmarks addObject:[NSNumber numberWithInteger:currentLine]];
    }
    [self refreshMinimap];
}

#pragma mark ivars
- (void)saveValue:(id)value toIvar:(NSString*)key {
    NSMutableDictionary* ivars = [[TextmateMinimap instance] getIVarsFor:self];
    [ivars setObject:value forKey:key];
}

- (id)getIVar:(NSString*)key {
    NSMutableDictionary* ivars = [[TextmateMinimap instance] getIVarsFor:self];
    return [ivars objectForKey:key];
}

- (void)MM_dealloc {
    [[TextmateMinimap instance] releaseIVarsFor:self];
    [self MM_dealloc];
}

#pragma mark misc
- (float)getScrollbarValue {
    NSScrollView* sv = (NSScrollView*)[[self superview] superview];
    float scrollbarPos = [[sv verticalScroller] floatValue];
    return scrollbarPos;
}

@end
