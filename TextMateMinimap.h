//
//  TextmateMinimap.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ShortcutRecorder/SRRecorderControl.h"
#import "MMSparkle/MMSUUpdater.h"

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

	IBOutlet NSView* preferencesView;
	IBOutlet NSTextField* explanationText;
	IBOutlet NSTextField* scaleUpThresholdPixelField;
	IBOutlet NSTextField* scaleUpToPixelField;
	IBOutlet SRRecorderControl* keyRecorder;
	
	MMSUUpdater* sparkleUpdater;
}
@property(retain) NSWindowController* lastWindowController;
@property(retain, readonly) NSImage* iconImage;
@property(retain, readonly) NSView* preferencesView;
@property(retain) NSTimer* timer;
@property(retain, readonly) NSLock* theLock;

+ (TextmateMinimap*)instance;
- (id)initWithPlugInController:(id <TMPlugInController>)aController;
- (void)setMinimapMenuItem:(BOOL)flag;

- (IBAction)update:(id)sender;
- (IBAction)changeScaleValues:(id)sender;
- (IBAction)resetDefaultScaleValues:(id)sender;
- (IBAction)changeMinimapSide:(id)sender;
- (MMSUUpdater*)updater;


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
