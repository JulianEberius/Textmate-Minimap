//
//  BackgroundUpdater.m
//  Textmate-Minimap
//
//  Created by Julian Eberius on 20.03.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import "BackgroundUpdater.h"
#include "math.h"
#import "MinimapView.h"
#import "AsyncBGDrawOperation.h"
#define REGION_LENGTH 200

@implementation BackgroundUpdater

- (id)initWithMinimapView:(MinimapView*)mv andOperationQueue:(NSOperationQueue*)opQueue
{
  self = [super init];
    if (self) {
    minimapView = mv;
    operationQueue = opQueue;
    dirtyRegions = [[NSMutableArray arrayWithCapacity:[[minimapView theImage] size].height/REGION_LENGTH] retain];
  }
  return self;
}

- (void) dealloc
{
  [super dealloc];
  [dirtyRegions release];
}

- (void)startRedrawInBackground
{
  NSRect visRect = [minimapView visiblePartOfTextView];
  [operationQueue cancelAllOperations];
  [operationQueue setSuspended:YES];
  for (NSValue* val in dirtyRegions) {
    NSRange range = [val rangeValue];
    NSRect rectToDraw = NSMakeRect(visRect.origin.x, range.location-1, visRect.size.width, range.length+1);
    AsyncBGDrawOperation* op = [[[AsyncBGDrawOperation alloc] initWithMinimapView:minimapView andUpdater:self] autorelease];
    [op setPartToDraw:rectToDraw andRangeObject:(NSValue*)val];
    [operationQueue addOperation:op];
  }
  [operationQueue setSuspended:NO];
}

- (void)rangeWasRedrawn:(NSValue*)range
{
  [dirtyRegions removeObject:range];
}

- (void)setDirtyExceptForVisiblePart
{
  [dirtyRegions removeAllObjects];
  NSImage* image = [minimapView theImage];
  NSRect visRect = [minimapView visiblePartOfTextView];
  int i = visRect.origin.y+visRect.size.height;
  int t = visRect.origin.y;
  BOOL goUp = TRUE;
  BOOL goDown = TRUE;
  while (goUp || goDown) {
    if (goDown) {
      int length = REGION_LENGTH;
      if ((i+length) > [image size].height) {
        length = [image size].height - i;
      }
      NSRange range = NSMakeRange(i, length+1);
      [self setRangeDirty:range];
      i=i+REGION_LENGTH;
      if (i>[image size].height)
        goDown = FALSE;
    }
    if (goUp) {
      int length = REGION_LENGTH;
      if ((t-length) < 0) {
        length = t;
      }
      NSRange range = NSMakeRange(t-length+1, length+1);
      [self setRangeDirty:range];
      t = t-REGION_LENGTH;
      if (t<0)
        goUp = FALSE;
    }
  }
}

- (void)setRangeDirty:(NSRange)range
{
  NSValue* val = [NSValue valueWithRange:range];
/*
  for (NSValue* v in dirtyRegions)
    if ([v isEqualToValue:val]) {
      return;
    }
  */
  [dirtyRegions addObject:val];
}

- (void)addDirtyRegions:(NSArray *)regions
{
  [dirtyRegions addObjectsFromArray:regions];
}

- (void)setCompleteImageDirty
{
  [dirtyRegions removeAllObjects];
  NSImage* image = [minimapView theImage];
  int i;
  for (i=0;i<[image size].height;i=i+REGION_LENGTH) {
    int length = REGION_LENGTH;
    if ((i+length) > [image size].height) {
      length = [image size].height - i;
    }
    NSRange range = NSMakeRange(i-1,length+1);
    [dirtyRegions addObject:[NSValue valueWithRange:range]];
  }
}
@end
