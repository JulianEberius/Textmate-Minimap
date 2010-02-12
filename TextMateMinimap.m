//
//  TextmateMinimap.m
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import "TextmateMinimap.h"
#import <Cocoa/Cocoa.h>
#import "TextMate.h"
#import "JRSwizzle.h"
#import "NSWindowController+Minimap.h"
#import "MinimapView.h"
#import "objc/runtime.h"


//TODO: improve performance for longer documents
//TODO: (maybe) support for 10.4

/*
 Notizen: nochmal den lock um switchtab und draw probiern, dazu deas zeichnen in N kleine NSOperation aufteilen, um es leichter canceln zu können 
 --> zeichnen im hintergrund muss sein!
 */

@implementation TextmateMinimap

static TextmateMinimap *sharedInstance = nil;

@synthesize timer;

#pragma mark public-api

+ (TextmateMinimap*)instance
{
    @synchronized(self) {
        if (sharedInstance == nil) {
            [[self alloc] init];
        }
    }
    return sharedInstance;
}


- (id)initWithPlugInController:(id <TMPlugInController>)aController
{
	if (self = [super init]) {
		
		[self installMenuItem];
		
		[OakProjectController jr_swizzleMethod:@selector(windowDidLoad) withMethod:@selector(MM_windowDidLoad) error:NULL];
		[OakProjectController jr_swizzleMethod:@selector(windowWillClose:) withMethod:@selector(MM_windowWillClose:) error:NULL];
		[OakDocumentController jr_swizzleMethod:@selector(windowDidLoad) withMethod:@selector(MM_windowDidLoad) error:NULL];
		[OakDocumentController jr_swizzleMethod:@selector(windowWillClose:) withMethod:@selector(MM_windowWillClose:) error:NULL];
		[NSWindow jr_swizzleMethod:@selector(setRepresentedFilename:) withMethod:@selector(MM_setRepresentedFilename:) error:NULL];
		[NSWindow jr_swizzleMethod:@selector(setDocumentEdited:) withMethod:@selector(MM_setDocumentEdited:) error:NULL];
		[NSWindow jr_swizzleMethod:@selector(becomeMainWindow) withMethod:@selector(MM_becomeMainWindow) error:NULL];
		[NSScrollView jr_swizzleMethod:@selector(reflectScrolledClipView:) withMethod:@selector(MM_reflectScrolledClipView:) error:NULL];
		[OakTextView jr_swizzleMethod:@selector(keyUp:) withMethod:@selector(MM_keyUp:) error:NULL];
		[OakTextView jr_swizzleMethod:@selector(mouseUp:) withMethod:@selector(MM_mouseUp:) error:NULL];
		[OakTextView jr_swizzleMethod:@selector(undo:) withMethod:@selector(MM_undo:) error:NULL];
		[OakTextView jr_swizzleMethod:@selector(redo:) withMethod:@selector(MM_redo:) error:NULL];
		[OakTextView jr_swizzleMethod:@selector(toggleSoftWrap:) withMethod:@selector(MM_toggleSoftWrap:) error:NULL];
		[OakTabBar jr_swizzleMethod:@selector(selectTab:) withMethod:@selector(MM_selectTab:) error:NULL];
		 
	}
	return self;
	
}

- (void)installMenuItem
{
	if(windowMenu = [[[[NSApp mainMenu] itemWithTitle:@"View"] submenu] retain])
	{
		NSArray* items = [windowMenu itemArray];
		
		int index = 0;
		for (NSMenuItem* item in items)
		{
			if ([[item title] isEqualToString:@"Show/Hide Project Drawer"])
			{
				index = [items indexOfObject:item]+1;
			} 
		}
		showMinimapMenuItem = [[NSMenuItem alloc] initWithTitle:@"Hide Minimap" action:@selector(toggleMinimap:) keyEquivalent:@""];
		[showMinimapMenuItem setKeyEquivalent:@"m"];
		[showMinimapMenuItem setKeyEquivalentModifierMask:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask];
		[showMinimapMenuItem setTarget:self];
		[windowMenu insertItem:showMinimapMenuItem atIndex:index];
	}
}

- (void)uninstallMenuItem
{
	[windowMenu removeItem:showMinimapMenuItem];
	
	[showMinimapMenuItem release];
	showMinimapMenuItem = nil;
	
	[windowMenu release];
	windowMenu = nil;
}

- (void)setMinimapMenuItem:(BOOL)flag
{
	if (flag)
		[showMinimapMenuItem setTitle:@"Hide Minimap"];
	else
		[showMinimapMenuItem setTitle:@"Show Minimap"];
}

- (void) toggleMinimap:(id)sender
{
		
	NSWindowController* wc = [[NSApp mainWindow] windowController];
	if ([wc isKindOfClass:OakProjectController] || [wc isKindOfClass:OakDocumentController])
	{
		//change menu item
		if ([[(NSMenuItem*)sender title] isEqualToString:@"Show Minimap"])
			[self setMinimapMenuItem:YES];
		else
			[self setMinimapMenuItem:NO];
		
		// move drawer
		[wc toggleMinimap];
	}
}
		 
- (void)dealloc
{
	[self uninstallMenuItem];
	[sharedInstance release];
	sharedInstance = nil;
	if (timer)
	{
		[timer release];
		timer = NULL;
	}
	[super dealloc];
}

#pragma mark singleton

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; //on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (NSUInteger)retainCount
{
    return UINT_MAX;  //denotes an object that cannot be released
}

- (void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

@end
