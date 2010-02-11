//
//  NSWindowController+Minimap.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface  NSWindowController (MM_NSWindowController)
	
#pragma mark new-api
- (int)getCurrentLine:(id)textView;
- (void)scrollToLine:(unsigned int)newLine;
- (void)refreshMinimap;
- (void)toggleMinimap;

#pragma mark swizzled-methods
- (void)MM_windowWillClose:(id)aNotification;
- (void)MM_windowDidLoad;

@end
