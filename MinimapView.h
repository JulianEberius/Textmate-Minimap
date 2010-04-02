//
//  MinimapView.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BackgroundUpdater.h"

extern int const scaleDownThreshold;
extern int const scaleDownTo;

@interface MinimapView : NSView {

  NSWindowController* windowController;
  NSView* textView;
  NSImage* theImage;
  NSOperationQueue* queue;
  NSTimer* timer;
  NSLock* drawLock;
  BackgroundUpdater* updater;

  float lastScrollPosition;

  NSRange viewableRange;
  float visRectPosBeforeScrolling;
  NSRect visiblePartOfImage;
  Boolean refreshAll;
  Boolean minimapIsScrollable;
  float pixelPerLine;
  float viewableRangeScale;
  int minimapLinesStart;
  int gutterSize;
  Boolean firstDraw;
  Boolean isDirty;
}
#pragma mark public-properties
@property(retain) NSWindowController* windowController;
@property(readonly) NSView* textView;
@property(readonly) NSImage* theImage;
@property(retain) NSTimer* timer;
@property(readonly) NSLock* drawLock;

#pragma mark init
- (id)initWithTextView:(NSView*) textView;

#pragma mark public-api
- (void)refreshDisplay;
- (void)refreshViewableRange;
- (void)smallRefresh;
- (int)gutterSize;
- (void)updateGutterSize;
- (void)setNewDocument;
- (NSRect)getVisiblePartOfMinimap;
- (void)setDirty;

#pragma mark drawOperation-api
- (void)asyncDrawFinished:(NSImage*) bitmap;
- (void)setViewableRangeScaling:(float)scale;
- (void)setMinimapLinesStart:(int)start;
- (int)getNumberOfLines;

@end
