//
//  NSWindowController+Preferences.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 25.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//
// This reuses a lot of code from Ciarán Walsh's ProjectPlus ( http://ciaranwal.sh/2008/08/05/textmate-plug-in-projectplus )
// Source: git://github.com/ciaran/projectplus.git

#import <Cocoa/Cocoa.h>

@interface NSWindowController (MM_Preferences)
- (NSArray*)MM_toolbarAllowedItemIdentifiers:(id)sender;
- (NSArray*)MM_toolbarDefaultItemIdentifiers:(id)sender;
- (NSArray*)MM_toolbarSelectableItemIdentifiers:(id)sender;
- (NSToolbarItem*)MM_toolbar:(NSToolbar*)toolbar itemForItemIdentifier:(NSString*)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
- (void)MM_selectToolbarItem:(id)item;
@end