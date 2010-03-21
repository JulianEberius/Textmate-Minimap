//
//  NewAsyncDrawOperation.h
//  Textmate-Minimap
//
//  Created by Julian Eberius on 19.03.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MinimapView.h"

#define MM_COMPLETE_IMAGE 0
#define MM_PARTIAL_IMAGE 1
#define MM_BACKGROUND_DRAW 2


@interface AsyncDrawOperation : NSOperation
{
	MinimapView* minimapView;
	int mode;
	NSColor* fillColor;
	NSRect partToDraw;
}

- (id)initWithMinimapView:(MinimapView*)mv andMode:(int)mode;
- (void)setPartToDraw:(NSRect)part;
@end