//
//  NSScrollView+Minimap.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSScrollView (MM_NSScrollView)
- (void)MM_reflectScrolledClipView:(NSClipView*)clipView;
@end
