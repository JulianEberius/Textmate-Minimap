//
//	MinimapView.h
//	TextmateMinimap
//
//	Created by Julian Eberius on 09.02.10.
//	Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern int const scaleDownThreshold;
extern int const scaleDownTo;
extern int const scaleUpThreshold;
extern int const scaleUpTo;

@interface MinimapView : NSView {

	NSWindowController* windowController;

	NSView* textView;
	NSRange viewableRange;
	NSImage* nextImage;
	NSOperationQueue* queue;
	
	Boolean refreshAll;
	float pixelPerLine;
	float viewableRangeScale;
	int minimapLinesStart;
	int gutterSize;
}
#pragma mark public-properties
@property(retain) NSWindowController* windowController;
@property(readonly) int gutterSize;
@property(readonly) NSView* textView;

#pragma mark init
- (id)initWithTextView:(NSView*) textView;

#pragma mark public-api
- (void)refreshDisplay;
- (void)refreshViewableRange;
- (void)updateGutterSize;

#pragma mark drawOperation-api
- (void)asyncDrawFinished:(NSImage*) bitmap;
- (void)setViewableRangeScaling:(float)scale;
- (void)setMinimapLinesStart:(int)start;
- (int)getNumberOfLines;

@end
