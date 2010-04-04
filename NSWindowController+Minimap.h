//
//  NSWindowController+Minimap.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MinimapView;

@interface  NSWindowController (MM_NSWindowController)
	
#pragma mark new-api
- (int)getCurrentLine:(id)textView;
- (void)scrollToLine:(unsigned int)newLine;
- (void)refreshMinimap;
- (void)toggleMinimap;
- (BOOL)isSoftWrapEnabled;
- (MinimapView*)getMinimapView;
- (NSDrawer*)getMinimapDrawer;
- (void)updateTrailingSpace;

#pragma mark swizzled-methods
- (void)MM_windowWillClose:(id)aNotification;
- (void)MM_windowDidLoad;
- (void)MM_toggleGroupsAndFilesDrawer:(id)sender;

// for the OakPrefManager
- (void)MM_PrefWindowWillClose:(id)arg1;
@end
