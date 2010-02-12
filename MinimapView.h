//
//  MinimapView.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MinimapView : NSView {
	NSLock*	theLock;
	NSView* _textView;
	
	NSRange _viewableRange;
	NSImage* _nextImage;
	NSOperationQueue* _queue;
	
	NSWindowController* windowController;
	
	Boolean _refreshAll;
	Boolean _refreshViewableRange;
	
	float _pixelPerLine;
}
#pragma mark public-properties
@property(retain) NSWindowController* windowController;
@property(retain, readonly) NSLock*	theLock;

#pragma mark public-api
- (id)initWithTextView:(NSView*) textView;

- (NSRange)viewableRange;
- (void)refreshDisplay;
- (void)refreshViewableRange;
- (NSView*)textView;
@end
