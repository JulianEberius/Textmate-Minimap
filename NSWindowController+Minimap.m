//
//  NSWindowController+Minimap.m
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import "NSWindowController+Minimap.h"
#import "MinimapView.h"
#import "TextMate.h"
#import "TextMateMinimap.h"
#import "objc/runtime.h"

// stuff that the textmate-windowcontrollers (OakProjectController, OakDocumentControler) implement 
@interface NSWindowController (TextMate_WindowControllers_Only)
- (id)textView;
- (void)goToLineNumber:(id)newLine;
- (unsigned int)getLineHeight;
@end

@interface NSWindowController (Private_MM_NSWindowController)
- (NSRectEdge) getCorrectMinimapDrawerSide;
@end

@implementation NSWindowController (MM_NSWindowController)

/*
 Request a redraw of the minimap
 */
- (void)refreshMinimap 
{
	NSWindow* window = [self window];
	for (NSDrawer *drawer in [window drawers])
		if ([[drawer contentView] isKindOfClass:[MinimapView class]] )  {
			MinimapView* textShapeView = (MinimapView*)[drawer contentView];
			[textShapeView refreshDisplay];	
		}
}

/*
 Get the currently selected line in the TextView, tip from TM plugin mailing list
 */
- (int)getCurrentLine:(id)textView
{
	NSMutableDictionary* dict = [NSMutableDictionary dictionary];
	[textView bind:@"lineNumber" toObject:dict  
	   withKeyPath:@"line"   options:nil];
	int line = [(NSNumber*)[dict objectForKey:@"line"] intValue];
	// unbinding (cleanup) would be nice, but calling unbind also deletes a binding that is needed by TextMate
	//[textView unbind:@"lineNumber"];
	return line;
}

/*
 Open / close the minimap drawer
 */
- (void)toggleMinimap
{
	NSWindow* window = [self window];
	for (NSDrawer *drawer in [window drawers])
		if ([[drawer contentView] isKindOfClass:[MinimapView class]] )  {
			int state = [drawer state];
			if (state == NSDrawerClosedState || state == NSDrawerClosingState)
			{
				NSRectEdge edge = [self getCorrectMinimapDrawerSide];
				[drawer openOnEdge:edge];
			}
			else 
				[drawer close];
		}
			
}

/*
 Call TextMate's gotoLine function 
 */
- (void)scrollToLine:(unsigned int)newLine
{
	NSWindow* window = [self window];
	for (NSDrawer *drawer in [window drawers])
		if ([[drawer contentView] isKindOfClass:[MinimapView class]] )  {
			id textView = [self textView];
			MinimapView* textShapeView = (MinimapView*)[drawer contentView];
			
			[textView goToLineNumber: [NSNumber numberWithInt:newLine]];
			[textShapeView refreshDisplay];
		}
}

/*
 Find out whether soft wrap is enabled by looking at the applications main menu... any better way to find that out?
 */
- (BOOL) isSoftWrapEnabled
{
	NSMenu* viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
	for (NSMenuItem* item in [viewMenu itemArray])
	{
		if ([[item title] isEqualToString:@"Soft Wrap"])
		{
			return [item state];
		}
	}
	return NO;
}

/*
 Get this window's minimap
 */
- (MinimapView*) minimap
{
	MinimapView* result = nil;
	for (NSDrawer *drawer in [[self window] drawers])
		if ([[drawer contentView] isKindOfClass:[MinimapView class]] )  {
			result = (MinimapView*)[drawer contentView];
		}
	return result;
}



#pragma mark swizzled_methods

/*
 Swizzled method: on close, release  minimapDrawer, set lastWindowController to nil
 */
- (void)MM_windowWillClose:(id)aNotification
{
	for (NSDrawer *drawer in [[self window] drawers])
		if ([[drawer contentView] isKindOfClass:[MinimapView class]] )  {
			[drawer setContentView:nil];
			[drawer setParentWindow:nil];
		}
	[[TextmateMinimap instance] setLastWindowController:nil];
	// call original
    [self MM_windowWillClose:aNotification];
}

/*
 Swizzled Method: called when an project or document window was openened
 - set the "lastWindowController" (top most window as seen by the plugin)
 - create a drawer for the minimap and set it's side
 - set the correct offsets for the minimap (different for document and project controller)
 */
- (void)MM_windowDidLoad
{
    // call original
    [self MM_windowDidLoad];
	
	[[TextmateMinimap instance] setLastWindowController:self];
	
    NSWindow* window=[self window];
	NSSize contentSize = NSMakeSize(160, [window frame].size.height);

	NSRectEdge edge = [self getCorrectMinimapDrawerSide];
	
	id minimapDrawer = [[NSDrawer alloc] initWithContentSize:contentSize preferredEdge:edge];
	[minimapDrawer setParentWindow:window];
	
	// init textshapeview
    MinimapView* textshapeView=  [[MinimapView alloc] initWithTextView:[self textView]];
	[textshapeView setWindowController:self];
	
	if ([[self className] isEqualToString:@"OakProjectController"]) {
		[minimapDrawer setTrailingOffset:56];
		[minimapDrawer setLeadingOffset:24];
	}
	else if ([[self className] isEqualToString:@"OakDocumentController"]) {
		[minimapDrawer setTrailingOffset:56];
		[minimapDrawer setLeadingOffset:0];
	}
	
	[minimapDrawer setContentView:textshapeView];
	[minimapDrawer openOnEdge:edge];

	[minimapDrawer release];
	[textshapeView release];
}

/*
 Swizzled method: called when the project drawer is opened or closed
 */
- (void)MM_toggleGroupsAndFilesDrawer:(id)sender
{
	[self MM_toggleGroupsAndFilesDrawer:sender];
	// if auto-mode is set, we need to check whether both drawers are now on the same side, in which case we need to 
	// close the minimap and reopen it on the other side
	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"Minimap_minimapSide"] == MinimapAutoSide) {
		// the following code is quite ugly... well it works for now :-) 
		NSDrawer* projectDrawer = nil;
		NSDrawer* minimapDrawer = nil;
		for (NSDrawer *drawer in [[self window] drawers])
			if (! [[drawer contentView] isKindOfClass:[MinimapView class]]) 
				projectDrawer = drawer;
			else if ([[drawer contentView] isKindOfClass:[MinimapView class]]) 
				minimapDrawer = drawer;

		if (projectDrawer != nil && minimapDrawer != nil) {
			int projectDrawerState = [projectDrawer state];
			if ((projectDrawerState == NSDrawerOpeningState) || (projectDrawerState == NSDrawerOpenState)) 
			{
				if ([projectDrawer edge] == [minimapDrawer edge])
				{
					[minimapDrawer close];
					[[NSNotificationCenter defaultCenter] addObserver:self
															 selector:@selector(reopenMinimapDrawer:)
																 name:NSDrawerDidCloseNotification object:minimapDrawer];
				}
			}
		}
	}
}

/*
 Private method: called by NSNotificationCenter when the minimapDrawer sends "DidClose"
 reopen minimapDrawer on the opposite side
 */
- (void)reopenMinimapDrawer:(NSNotification *)notification
{
	for (NSDrawer *drawer in [[self window] drawers])
		if ([[drawer contentView] isKindOfClass:[MinimapView class]]) 
		{
			if ([drawer edge] == NSMaxXEdge)
				[drawer openOnEdge:NSMinXEdge];
			else
				[drawer openOnEdge:NSMaxXEdge];
			
			[[NSNotificationCenter defaultCenter] removeObserver:self name:NSDrawerDidCloseNotification object:drawer];
		}
}

/*
 Find out on which side the minimap drawer should appear
 */
- (NSRectEdge) getCorrectMinimapDrawerSide
{
	int result;
	NSRectEdge projectDrawerSide = NSMinXEdge;
	switch ([[NSUserDefaults standardUserDefaults] integerForKey:@"Minimap_minimapSide"]) {
		default:
		case MinimapAutoSide:
			for (NSDrawer *drawer in [[self window] drawers])
			{
				if (![[drawer contentView] isKindOfClass:[MinimapView class]])  {
					projectDrawerSide = [drawer edge];
				}
			}
			if (projectDrawerSide == NSMaxXEdge) 
				result = NSMinXEdge;
			else 
				result = NSMaxXEdge;
			break;
			
		case MinimapLeftSide:
			result = NSMinXEdge;
			break;
			
		case MinimapRightSide:
			result = NSMaxXEdge;
			break;
	}
	
	return result;
}

@end
