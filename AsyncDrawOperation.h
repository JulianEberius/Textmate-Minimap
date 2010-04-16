//
//  NewAsyncDrawOperation.h
//  Textmate-Minimap
//
//  Created by Julian Eberius on 19.03.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MinimapView;
@class BackgroundUpdater;

#define MM_COMPLETE_IMAGE 0
#define MM_PARTIAL_IMAGE 1

@interface AsyncDrawOperation : NSOperation
{
  MinimapView* minimapView;
  BackgroundUpdater* updater;
  int mode;
  NSColor* fillColor;
  NSRect partToDraw;
}

// asyncdrawop has two different usage variants at the moment.. should be split into two classes
// first usage variant
- (id)initWithMinimapView:(MinimapView*)mv andMode:(int)mode;
- (void)setPartToDraw:(NSRect)part; 
@end