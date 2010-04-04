//
//  AsyncBGDrawOperation.h
//  Textmate-Minimap
//
//  Created by Julian Eberius on 23.03.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MinimapView;
@class BackgroundUpdater;

@interface AsyncBGDrawOperation : NSOperation
{
  MinimapView* minimapView;
  BackgroundUpdater* updater;
  NSColor* fillColor;
  NSValue* rangeObject;
  NSRect partToDraw;
}

- (id)initWithMinimapView:(MinimapView*)mv andUpdater:(BackgroundUpdater*)updater;
- (void)setPartToDraw:(NSRect)part andRangeObject:(NSValue*)range; 
@end