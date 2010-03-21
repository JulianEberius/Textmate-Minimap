//
//  BackgroundUpdater.m
//  Textmate-Minimap
//
//  Created by Julian Eberius on 20.03.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BackgroundUpdater.h"
#include "math.h"
#import "MinimapView.h"
#import "AsyncDrawOperation.h"

@implementation BackgroundUpdater

- (id)initWithMinimapView:(MinimapView*)mv andOperationQueue:(NSOperationQueue*)opQueue
{
	self = [super init];
    if (self) {
		minimapView = mv;
		operationQueue = opQueue;
	}
    return self;
}

- (void) dealloc
{
	[super dealloc];
}

- (void)startRedrawInBackground
{
	NSImage* image = [minimapView theImage];
	NSRect visRect = [minimapView getVisiblePartOfMinimap];
	
	int i;
	for (i=visRect.origin.y+visRect.size.height;
		 i<[image size].height;
		 i=i+50) {
		
		int length = 50;
		if ((i+length) > [image size].height) {
			length = [image size].height - i;
		}
		
		NSRect rectToDraw = NSMakeRect(visRect.origin.x, i-1, visRect.size.width, length+1);
		AsyncDrawOperation* op = [[[AsyncDrawOperation alloc] initWithMinimapView:minimapView andMode:MM_BACKGROUND_DRAW] autorelease];
		[op setPartToDraw:rectToDraw];
		[operationQueue addOperation:op];
	}
	for (i=visRect.origin.y;
		 i>0;
		 i=i-50) {
		
		int length = 50;
		if ((i-length) < 0) {
			length = i;
		}
		
		NSRect rectToDraw = NSMakeRect(visRect.origin.x, i-length-1, visRect.size.width, length+1);
		AsyncDrawOperation* op = [[[AsyncDrawOperation alloc] initWithMinimapView:minimapView andMode:MM_BACKGROUND_DRAW] autorelease];
		[op setPartToDraw:rectToDraw];
		[operationQueue addOperation:op];
	}
}
@end
