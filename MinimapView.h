//
//  MinimapView.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MinimapView : NSView {
	
	NSView* _textView;
	int _numLines;
	
	NSRange _viewableRange;
	NSImage* _nextImage;
	NSOperationQueue* _queue;
	
	NSWindowController* windowController;
	
	Boolean _refreshAll;
	Boolean _refreshViewableRange;
	
	float _pixelPerLine;
	Boolean _needsNewImage;
}
#pragma mark public-properties
@property(retain) NSWindowController* windowController;

#pragma mark public-api
- (id)initWithTextView:(NSView*) textView;

- (BOOL)needsNewImage;
- (void)setNeedsNewImage:(BOOL)flag;
- (void)setMinimapImage:(NSImage *)image;

- (void)refreshDisplay;
- (void)refreshViewableRange;
@end
