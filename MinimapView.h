//
//  MinimapView.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//
// Documentation in the .m file

#import <Cocoa/Cocoa.h>
@class BackgroundUpdater;

extern int const scaleDownThreshold;
extern int const scaleDownTo;

@interface MinimapView : NSView {
  NSWindowController* windowController;
  NSView* textView;
  NSImage* theImage;
  NSOperationQueue* queue;
  NSTimer* timer;
  NSTimer* firstDrawTimer;
  //NSLock* drawLock;
  BackgroundUpdater* updater;

  NSRange viewableRange;
  NSRect visiblePartOfTextView;
  NSRect drawnRect;
  Boolean requestRedraw;
  Boolean minimapIsScrollable;
  Boolean firstDraw;
  Boolean dirty;
  float pixelPerLine;
  float viewableRangeScaling;
  float visRectPosBeforeScrolling;
  float lastScrollPosition;
  int minimapLinesStart;
  int gutterSize;
}
#pragma mark public-properties
@property float viewableRangeScaling;
@property int minimapLinesStart;
@property Boolean dirty;
@property(assign) NSWindowController* windowController;
@property(readonly) int gutterSize;
@property(readonly) NSRect visiblePartOfTextView;
@property(readonly, assign) NSView* textView;
@property(readonly, retain) NSImage* theImage;
@property(retain) BackgroundUpdater* updater;
//@property(readonly, retain) NSLock* drawLock;
@property(retain) NSTimer* timer;

#pragma mark init
- (id)initWithTextView:(NSView*) textView andWindowController:(NSWindowController*) controller;

#pragma mark public-api
- (void)refresh;
- (void)firstRefresh;
- (void)repaint;
- (void)reactToScrollingTextView;
- (int)gutterSize;
- (void)setNewDocument;
- (int)numberOfLines;
- (void)asyncDrawFinished:(NSImage*) bitmap;

#pragma mark private-methods
- (void)updateGutterSize;
- (unsigned int)absoluteLineIdxFromPoint:(NSPoint)mouseLoc;
@end