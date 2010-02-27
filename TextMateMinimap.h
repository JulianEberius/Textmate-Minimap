//
//  TextmateMinimap.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ShortcutRecorder/SRRecorderControl.h"

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
}
@property(retain) NSWindowController* lastWindowController;
@property(retain, readonly) NSImage* iconImage;
@property(retain, readonly) NSView* preferencesView;
@property(retain) NSTimer* timer;
@property(retain, readonly) NSLock* theLock;

+ (TextmateMinimap*)instance;
- (id)initWithPlugInController:(id <TMPlugInController>)aController;
- (void)setMinimapMenuItem:(BOOL)flag;

- (IBAction)changeScaleValues:(id)sender;
- (IBAction)resetDefaultScaleValues:(id)sender;
- (IBAction)changeMinimapSide:(id)sender;

enum MinimapSideModes {
	MinimapLeftSide = 0,
	MinimapRightSide = 1,
	MinimapAutoSide = 2
};

@end
