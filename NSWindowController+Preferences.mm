//
//  NSWindowController+Preferences.m
//  TextmateMinimap
//
//  Created by Julian Eberius on 25.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

// This reuses a lot of code from Ciarán Walsh's ProjectPlus ( http://ciaranwal.sh/2008/08/05/textmate-plug-in-projectplus )
// Source: git://github.com/ciaran/projectplus.git

#import "NSWindowController+Preferences.h"
#import "TextmateMinimap.h"
#import "TextMate.h"

float ToolbarHeightForWindow(NSWindow *window)
{
  NSToolbar *toolbar;
  float toolbarHeight = 0.0;
  NSRect windowFrame;

  toolbar = [window toolbar];

  if(toolbar && [toolbar isVisible])
  {
    windowFrame   = [NSWindow contentRectForFrameRect:[window frame] styleMask:[window styleMask]];
    toolbarHeight = NSHeight(windowFrame) - NSHeight([[window contentView] frame]);
  }

  return toolbarHeight;
}

static const NSString* MINIMAP_PREFERENCES_LABEL = @"Minimap";

@implementation NSWindowController (MM_Preferences)
- (NSArray*)MM_toolbarAllowedItemIdentifiers:(id)sender
{
  return [[self MM_toolbarAllowedItemIdentifiers:sender] arrayByAddingObject:MINIMAP_PREFERENCES_LABEL];
}
- (NSArray*)MM_toolbarDefaultItemIdentifiers:(id)sender
{
  return [[self MM_toolbarDefaultItemIdentifiers:sender] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:MINIMAP_PREFERENCES_LABEL,nil]];
}
- (NSArray*)MM_toolbarSelectableItemIdentifiers:(id)sender
{
  return [[self MM_toolbarSelectableItemIdentifiers:sender] arrayByAddingObject:MINIMAP_PREFERENCES_LABEL];
}

- (NSToolbarItem*)MM_toolbar:(NSToolbar*)toolbar itemForItemIdentifier:(NSString*)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
  NSToolbarItem *item = [self MM_toolbar:toolbar itemForItemIdentifier:itemIdentifier willBeInsertedIntoToolbar:flag];
  if([itemIdentifier isEqualToString:MINIMAP_PREFERENCES_LABEL])
    [item setImage:[[TextmateMinimap instance] iconImage]];
  return item;
}

- (void)MM_selectToolbarItem:(id)item
{
  if ([[item label] isEqualToString:MINIMAP_PREFERENCES_LABEL]) {
    if ([[self valueForKey:@"selectedToolbarItem"] isEqualToString:[item label]]) return;
    [[self window] setTitle:[item label]];
    [self setValue:[item label] forKey:@"selectedToolbarItem"];
    
    NSSize prefsSize = [[[TextmateMinimap instance] preferencesView] frame].size;
    NSRect frame = [[self window] frame];
    prefsSize.width = [[self window] contentMinSize].width;

    [[self window] setContentView:[[TextmateMinimap instance] preferencesView]];

    float newHeight = prefsSize.height + ToolbarHeightForWindow([self window]) + 22;
    frame.origin.y += frame.size.height - newHeight;
    frame.size.height = newHeight;
    frame.size.width = prefsSize.width;
    [[self window] setFrame:frame display:YES animate:YES];
  } else {
    [self MM_selectToolbarItem:item];
  }
}
@end