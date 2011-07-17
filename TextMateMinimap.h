//
//  TextmateMinimap.h
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

#import <Cocoa/Cocoa.h>
#import "ShortcutRecorder/SRRecorderControl.h"
#import "Sparkle/SUUpdater.h"

@protocol TMPlugInController
- (float)version;
@end

@interface TextmateMinimap : NSObject {
  NSImage* iconImage;
  NSTimer* timer;
  NSLock* theLock;
  NSMenu* windowMenu;
  NSMenuItem* showMinimapMenuItem;
  NSWindowController* prefWindowController;
  NSWindowController* lastWindowController;
  
  NSMutableDictionary* iVars;

  IBOutlet NSView* preferencesView;
  IBOutlet NSTextField* explanationText;
  IBOutlet NSTextField* scaleUpThresholdPixelField;
  IBOutlet NSTextField* scaleUpToPixelField;
  IBOutlet SRRecorderControl* keyRecorder;
  
  SUUpdater* sparkleUpdater;
}
@property(retain) NSWindowController* lastWindowController;
@property(retain, readonly) NSImage* iconImage;
@property(retain, readonly) NSView* preferencesView;
@property(retain) NSTimer* timer;
@property(readonly) NSLock* theLock;

+ (TextmateMinimap*)instance;
- (id)initWithPlugInController:(id <TMPlugInController>)aController;
- (void)setMinimapMenuItem:(BOOL)flag;

//  simulating new fields(ivars) for the objects get extended via categories
- (NSMutableDictionary*)getIVarsFor:(id)sender;
- (void)releaseIVarsFor:(id)sender;

- (IBAction)update:(id)sender;
- (IBAction)changeScaleValues:(id)sender;
- (IBAction)resetDefaultScaleValues:(id)sender;
- (IBAction)changeMinimapSide:(id)sender;
- (SUUpdater*)updater;


enum MinimapSideModes {
  MinimapLeftSide = 0,
  MinimapRightSide = 1,
  MinimapAutoSide = 2
};
enum MinimapNewDocumentModes {
  MinimapInheritShow = 0,
  MinimapAlwaysShow = 1,
  MinimapNeverShow = 2
};
enum MinimapOpenDocumentModes {
  MinimapAsSaved = 0,
  MinimapAsNewDocument = 1,
};

@end
