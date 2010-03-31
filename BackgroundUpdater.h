//
//  BackgroundUpdater.h
//  Textmate-Minimap
//
//  Created by Julian Eberius on 20.03.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MinimapView;

@interface BackgroundUpdater : NSObject {
	MinimapView* minimapView;
	NSOperationQueue* operationQueue;
	NSMutableArray* queue;
	
	NSMutableArray* dirtyRegions;
}
- (id)initWithMinimapView:(MinimapView*)mv andOperationQueue:(NSOperationQueue*)opQueue;
- (void)startRedrawInBackground;

- (void)rangeWasRedrawn:(NSValue*)range;
- (void)setCompleteImageDirty;
- (void)setRangeDirty:(NSRange)range;
- (void)addDirtyRegions:(NSArray*)regions; //array of NSRanges
- (void)setCompleteImageDirty;
- (void)setDirtyExceptForVisiblePart;
@end
