//
//  TextmateMinimap.m
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//
// Central singleton representing the plugin itself.
//
// - installs menu item, swizzles a lot of TM's methods to integrate the minimap
// - contains a central lock used to prevent some race conditions between the drawing of TM and the plugin
// - contains the fake ivars for TM objects (they get extended via categories, which does not allow to add real ivars)
// - allows to toggle the minimap, and setting of the menu item label
// - initializes and deals with the preference additions

#import "TextmateMinimap.h"
#import <Cocoa/Cocoa.h>
#import "TextMate.h"
#import "JRSwizzle.h"
#import "NSWindowController+Minimap.h"
#import "NSWindowController+Preferences.h"
#import "MinimapView.h"
#import "objc/runtime.h"
#import "ShortcutRecorder/SRRecorderControl.h"
#import "ShortcutRecorder/SRCommon.h"


@interface TextmateMinimap (Private_TextMateMinimap)
- (void)toggleMinimap:(id)sender;
- (void)installMenuItem;
- (void)uninstallMenuItem;
- (void)dealloc;
@end

NSString* const explanationString1 = @"Explanation: based on the current "
    "height of the minimap (%ipx), documents with more than %i lines would "
    "be drawn only partially, with %ipx per line. \nSetting the first value "
    "to low can decrease performance!";
NSString* const explanationString2 = @"Explanation: based on a minimap with "
    "a height of %ipx, documents with more than %i lines would be drawn only "
    "partially, with %ipx per line. \nSetting the first value to low can decrease performance!";

@implementation TextmateMinimap

@synthesize timer, theLock, iconImage, preferencesView, lastWindowController;

static TextmateMinimap *sharedInstance = nil;

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
    
    NSString* iconPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"textmate-minimap" ofType:@"tiff"];
    iconImage = [[NSImage alloc] initByReferencingFile:iconPath];
    theLock = [[[NSLock alloc] init] retain];
    iVars = [[NSMutableDictionary dictionaryWithCapacity:10] retain];

    sparkleUpdater = [MMSUUpdater updaterForBundle:[NSBundle bundleForClass:[self class]]];
    [sparkleUpdater resetUpdateCycle];
    
    // swizzle textmate methods 
    [OakProjectController jr_swizzleMethod:@selector(windowDidLoad) withMethod:@selector(MM_windowDidLoad) error:NULL];
    [OakProjectController jr_swizzleMethod:@selector(windowWillClose:) withMethod:@selector(MM_windowWillClose:) error:NULL];
    [OakDocumentController jr_swizzleMethod:@selector(windowDidLoad) withMethod:@selector(MM_windowDidLoad) error:NULL];
    [OakDocumentController jr_swizzleMethod:@selector(windowWillClose:) withMethod:@selector(MM_windowWillClose:) error:NULL];
    [OakProjectController jr_swizzleMethod:@selector(toggleGroupsAndFilesDrawer:) 
                                withMethod:@selector(MM_toggleGroupsAndFilesDrawer:) error:NULL];
    [OakWindow jr_swizzleMethod:@selector(setRepresentedFilename:) withMethod:@selector(MM_setRepresentedFilename:) error:NULL];
    [OakWindow jr_swizzleMethod:@selector(setDocumentEdited:) withMethod:@selector(MM_setDocumentEdited:) error:NULL];
    [OakWindow jr_swizzleMethod:@selector(becomeMainWindow) withMethod:@selector(MM_becomeMainWindow) error:NULL];
    [NSScrollView jr_swizzleMethod:@selector(reflectScrolledClipView:) withMethod:@selector(MM_reflectScrolledClipView:) error:NULL];
    [OakTextView jr_swizzleMethod:@selector(keyDown:) withMethod:@selector(MM_keyDown:) error:NULL];
    [OakTextView jr_swizzleMethod:@selector(mouseUp:) withMethod:@selector(MM_mouseUp:) error:NULL];
    [OakTextView jr_swizzleMethod:@selector(mouseDown:) withMethod:@selector(MM_mouseDown:) error:NULL];
    [OakTextView jr_swizzleMethod:@selector(undo:) withMethod:@selector(MM_undo:) error:NULL];
    [OakTextView jr_swizzleMethod:@selector(redo:) withMethod:@selector(MM_redo:) error:NULL];
    [OakTextView jr_swizzleMethod:@selector(toggleSoftWrap:) withMethod:@selector(MM_toggleSoftWrap:) error:NULL];
    [OakTextView jr_swizzleMethod:@selector(toggleShowSoftWrapInGutter:) withMethod:@selector(MM_toggleShowSoftWrapInGutter:) error:NULL];
    [OakTextView jr_swizzleMethod:@selector(toggleLineNumbers:) withMethod:@selector(MM_toggleLineNumbers:) error:NULL];
    [OakTextView jr_swizzleMethod:@selector(toggleShowBookmarksInGutter:) 
                       withMethod:@selector(MM_toggleShowBookmarksInGutter:) error:NULL];
    [OakTextView jr_swizzleMethod:@selector(toggleFoldingsEnabled:) withMethod:@selector(MM_toggleFoldingsEnabled:) error:NULL];
    [OakTextView jr_swizzleMethod:@selector(dealloc) withMethod:@selector(MM_dealloc) error:NULL];
    [OakTabBar jr_swizzleMethod:@selector(selectTab:) withMethod:@selector(MM_selectTab:) error:NULL];

    // Prefs... this directly reuses a lot of code from Ciarán Walsh's ProjectPlus
    // http://ciaranwal.sh/2008/08/05/textmate-plug-in-projectplus
    // Source: git://github.com/ciaran/projectplus.git

    // setting userdefault-defaults
    [[NSUserDefaults standardUserDefaults]
     registerDefaults:[NSDictionary
      dictionaryWithObjects:[NSArray arrayWithObjects:
                    [NSNumber numberWithFloat:2.0],
                    [NSNumber numberWithInt:4],
                    [NSNumber numberWithInt:46], //this is "m"
                    [NSNumber numberWithInt:NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask],
                    [NSNumber numberWithInt:MinimapAutoSide],
                    [NSNumber numberWithInt:MinimapInheritShow],
                    [NSNumber numberWithInt:MinimapAsSaved],
                    [NSNumber numberWithBool:YES],
                    NULL
                  ]
             forKeys:[NSArray arrayWithObjects:
                    @"Minimap_scaleUpThreshold",
                    @"Minimap_scaleUpTo",
                    @"Minimap_triggerMinimapKeyCode",
                    @"Minimap_triggerMinimapKeyFlags",
                    @"Minimap_minimapSide",
                    @"Minimap_newDocumentBehaviour",
                    @"Minimap_openDocumentBehaviour",
                    @"Minimap_lastDocumentHadMinimapOpen",
                    NULL
                  ]]];

    NSString* nibPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Preferences" ofType:@"nib"];
    prefWindowController = [[NSWindowController alloc] initWithWindowNibPath:nibPath owner:self];
    [prefWindowController showWindow:self];
    
    [OakPreferencesManager jr_swizzleMethod:@selector(windowWillClose:) withMethod:@selector(MM_PrefWindowWillClose:) error:NULL];
    [OakPreferencesManager jr_swizzleMethod:@selector(toolbarAllowedItemIdentifiers:) 
                                 withMethod:@selector(MM_toolbarAllowedItemIdentifiers:) error:NULL];
    [OakPreferencesManager jr_swizzleMethod:@selector(toolbarDefaultItemIdentifiers:) 
                                 withMethod:@selector(MM_toolbarDefaultItemIdentifiers:) error:NULL];
    [OakPreferencesManager jr_swizzleMethod:@selector(toolbarSelectableItemIdentifiers:) 
                                 withMethod:@selector(MM_toolbarSelectableItemIdentifiers:) error:NULL];
    [OakPreferencesManager jr_swizzleMethod:@selector(toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:) 
                                 withMethod:@selector(MM_toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:) error:NULL];
    [OakPreferencesManager jr_swizzleMethod:@selector(selectToolbarItem:) withMethod:@selector(MM_selectToolbarItem:) error:NULL];
  }
  return self;
}



- (void)setMinimapMenuItem:(BOOL)flag
{
  if (flag)
    [showMinimapMenuItem setTitle:@"Hide Minimap"];
  else
    [showMinimapMenuItem setTitle:@"Show Minimap"];
}

- (NSMutableDictionary*)getIVarsFor:(id)sender
{
  if (iVars == nil)
    return nil;
  id x = [iVars objectForKey:[NSNumber numberWithInt:[sender hash]]];
  if (x == nil) {
    NSMutableDictionary* iVarHolder = [NSMutableDictionary dictionaryWithCapacity:2];
    [iVars setObject:iVarHolder forKey:[NSNumber numberWithInt:[sender hash]]];
    return iVarHolder;
  }
  return (NSMutableDictionary*)x;
}

- (void)releaseIVarsFor:(id)sender
{
  [iVars removeObjectForKey:[NSNumber numberWithInt:[sender hash]]];
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



#pragma mark private-methods
- (void)dealloc
{
  [self uninstallMenuItem];
  if (timer)
  {
    [timer release];
    timer = NULL;
  }
  [theLock release];
  [lastWindowController release];
  [prefWindowController release];
  [iVars release];
  [sharedInstance release];
  sharedInstance = nil;
  [super dealloc];
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
    showMinimapMenuItem = [[NSMenuItem alloc] initWithTitle:@"Hide Minimap" 
                                                     action:@selector(toggleMinimap:) keyEquivalent:@""];
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

#pragma mark prefs
- (void)awakeFromNib
{
  [self changeScaleValues:nil];
  [keyRecorder setKeyCombo:SRMakeKeyCombo(
      [[NSUserDefaults standardUserDefaults] integerForKey:@"Minimap_triggerMinimapKeyCode"],
      [[NSUserDefaults standardUserDefaults] integerForKey:@"Minimap_triggerMinimapKeyFlags"]
                                          )];
}

- (IBAction)update:(id)sender
{
  [sparkleUpdater checkForUpdates:nil];
}

- (IBAction)changeScaleValues:(id)sender
{
  float scaleUpThreshold = [[NSUserDefaults standardUserDefaults] floatForKey:@"Minimap_scaleUpThreshold"];
  int scaleUpTo = [[NSUserDefaults standardUserDefaults] integerForKey:@"Minimap_scaleUpTo"];

  NSWindowController* lwc = [self lastWindowController];
  int height;
  NSString* expStr;
  if (lwc != nil) {
    NSRect minimapBounds = [[lwc getMinimapView] bounds];
    height = floor(minimapBounds.size.height);
    expStr = explanationString1;
  }
  else {
    height = 500;
    expStr = explanationString2;
  }
  int lines = floor(height / scaleUpThreshold);

  NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
  [formatter setMaximumFractionDigits:2];
  [formatter setRoundingMode: NSNumberFormatterRoundDown];
  NSString* numberString = [formatter stringFromNumber:[NSNumber numberWithFloat:scaleUpThreshold]];
  [formatter release];

  [explanationText setStringValue:[NSString stringWithFormat:expStr, height, lines, scaleUpTo]];
  [scaleUpToPixelField setStringValue:[NSString stringWithFormat:@"%i",scaleUpTo]];
  [scaleUpThresholdPixelField setStringValue:numberString];

  if (lwc != nil)
    [[lwc getMinimapView] refresh];
}

- (IBAction)resetDefaultScaleValues:(id)sender
{
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  [defaults setFloat:2.0 forKey:@"Minimap_scaleUpThreshold"];
  [defaults setInteger:4 forKey:@"Minimap_scaleUpTo"];
  [self changeScaleValues:nil];
}

- (IBAction)changeMinimapSide:(id)sender
{
  int newMode = [(NSMatrix*)sender selectedRow];
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  [defaults setInteger:newMode forKey:@"Minimap_minimapSide"];
}

- (MMSUUpdater *)updater {
  return [MMSUUpdater updaterForBundle:[NSBundle bundleForClass:[self class]]];;
}

- (BOOL)shortcutRecorder:(SRRecorderControl *)aRecorder isKeyCode:(NSInteger)keyCode 
    andFlagsTaken:(NSUInteger)flags reason:(NSString **)aReason
{
  return NO;
}

- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo
{
  if (newKeyCombo.code != -1)
  {
    [showMinimapMenuItem setKeyEquivalent:[SRStringForKeyCode(newKeyCombo.code) lowercaseString]];
    [showMinimapMenuItem setKeyEquivalentModifierMask:newKeyCombo.flags];
  }
  else
  {
    [showMinimapMenuItem setKeyEquivalent:@""];
    [showMinimapMenuItem setKeyEquivalentModifierMask:0];
  }
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  [defaults setInteger:newKeyCombo.code forKey:@"Minimap_triggerMinimapKeyCode"];
  [defaults setInteger:newKeyCombo.flags forKey:@"Minimap_triggerMinimapKeyFlags"];
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
  if ([[tabViewItem identifier] isEqualToString:@"FineTuning"] ) {
    [self changeScaleValues:nil];
  }
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
