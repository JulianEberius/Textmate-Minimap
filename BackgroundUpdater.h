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
}
- (id)initWithMinimapView:(MinimapView*)mv andOperationQueue:(NSOperationQueue*)opQueue;
- (void)startRedrawInBackground;
- (void)firstDraw;
@end
