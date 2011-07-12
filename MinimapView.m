//
//  MinimapView.m
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import "MinimapView.h"
#import "NSView+Minimap.h"
#import "NSWindowController+Minimap.h"
#import "TextMate.h"
#import "BackgroundUpdater.h"
#import "TextmateMinimap.h"
#import "AsyncDrawOperation.h"
#import "AsyncDrawOperation.h"

int const scaleDownThreshold = 5;
int const scaleDownTo = 5;

@interface MinimapView (Private_MinimapView)
- (void)updateViewableRange;
- (void)drawVisRect:(NSRect)rect;
- (void)drawBookmarkOnLine:(unsigned)line toRect:(NSRect)drawTo;
- (void)updateVisiblePartOfTextView;
- (NSColor*)currentBackgroundColor;
- (void)fillWithBackground;
//- (void)firstRefresh;
@end

// stuff implemented by the TextMate textview
@interface NSView (MM_NSView_OnlyByOakTextView)
- (unsigned int)lineHeight;
- (id)currentStyleSheet;
@end

@implementation MinimapView

@synthesize windowController, textView, theImage, timer, 
    viewableRangeScaling, dirty, minimapLinesStart, gutterSize, visiblePartOfTextView, bookmarks;
//@synthesize drawLock;
  
#pragma mark init
- (id)initWithTextView:(NSView*) tv andWindowController:(NSWindowController*) controller;
{
  self = [super init];
  if (self) {
    queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:1];
    
    gutterSize = -1;
    visRectPosBeforeScrolling = -1;
    firstDraw = YES;
    
    [self setViewableRangeScaling:1.0];
    //drawLock = [[NSLock alloc] init];
    textView = tv;
    updater = [[BackgroundUpdater alloc] initWithMinimapView:self andOperationQueue:queue];
    [self setWindowController:controller];
    [self initializeBookmarks];
  }
  return self;
}

- (void)dealloc
{
  [queue cancelAllOperations];
  
  [theImage release];      
  theImage = nil;
  [updater release];
  updater = nil;
  [queue release];
  // [drawLock release];
  queue = nil;
  [super dealloc];
}

#pragma mark drawing routines
- (void)drawRect:(NSRect)rect
{
  if (firstDraw) {
    [windowController updateTrailingSpace];
    firstDraw = NO; 
    theImage = [[textView emptySnapshotImageFor:self] retain];
    [self fillWithBackground];
    [self setNeedsDisplay:NO];
    //Defer first drawing by small interval ... don't know a better way to wait till the tv is fully initialized
    if (firstDrawTimer != nil && [firstDrawTimer isValid]) {
      [firstDrawTimer invalidate];
      firstDrawTimer = nil;
    }
    firstDrawTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self 
                               selector:@selector(firstRefresh) userInfo:nil repeats:NO];
    return;
  }

  int numLines = [self numberOfLines];
  float ppl = [self bounds].size.height / numLines;
  float scaleUpThreshold = [[NSUserDefaults standardUserDefaults] floatForKey:@"Minimap_scaleUpThreshold"];
  NSRect drawTo = [self bounds];
  if (requestRedraw)
  {
    AsyncDrawOperation* op;
    if (ppl < scaleUpThreshold)
    {
      minimapIsScrollable = YES;
      [self updateVisiblePartOfTextView];
      op = [[AsyncDrawOperation alloc] initWithMinimapView:self andMode:MM_PARTIAL_IMAGE];
      [op setPartToDraw:visiblePartOfTextView];
      requestRedraw = NO;
    } else {
      minimapIsScrollable = NO;
      op = [[AsyncDrawOperation alloc] initWithMinimapView:self andMode:MM_COMPLETE_IMAGE];
    }
    [queue cancelAllOperations];
    [queue addOperation:op];
    //NSLog(@"adding op!");
    [op release];
    requestRedraw = NO;
    return;
  }
  if (ppl < scaleUpThreshold)
  {
    NSRect rectToSnapshot = visiblePartOfTextView;
    [theImage drawInRect:drawTo fromRect:rectToSnapshot operation:NSCompositeSourceOver fraction:1.0];
  }
  else
  {
    if (ppl > scaleDownThreshold) {
      drawTo.size.height = numLines*scaleDownTo;
      [[self currentBackgroundColor] set];
      NSRectFill(NSMakeRect(drawTo.origin.x, drawTo.size.height, 
              drawTo.size.width, [self bounds].size.height - drawTo.size.height));
    }
    [self setMinimapLinesStart:0];
    [self setViewableRangeScaling:1.0];
    [theImage drawInRect:drawTo fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
  }
  drawnRect = drawTo;
  [self drawVisRect:drawTo];

  // only draw bookmarks if softwrap is disabled
  // with softwrap, we wont know where to lines begin or end 
  if (![windowController isSoftWrapEnabled]) {
    NSEnumerator *e = [[self bookmarks] objectEnumerator];
    int bookmarkLine;
    id enumeratedObject;
    
    while ( (enumeratedObject = [e nextObject]) ) {
      bookmarkLine = [(NSNumber*)enumeratedObject intValue];
      [self drawBookmarkOnLine:bookmarkLine toRect:drawTo];
    }
  }
}

- (void)updateVisiblePartOfTextView
{
  NSRect bounds = [self visibleRect];
  int numLines = [self numberOfLines];

  NSSize imgSize = [theImage size];
  NSRect tvBounds   = [textView bounds];
  int scaleUpTo = [[NSUserDefaults standardUserDefaults] integerForKey:@"Minimap_scaleUpTo"];
  float visiblePercentage = bounds.size.height / (numLines*scaleUpTo);
  [self setViewableRangeScaling:(1/visiblePercentage)];


  NSScrollView* sv = (NSScrollView*)[[textView superview] superview];
  float percentage = [[sv verticalScroller] floatValue];

  float scaleFactor = [theImage size].height / tvBounds.size.height;
  float middle = (percentage*(tvBounds.size.height-[textView visibleRect].size.height) + [textView visibleRect].size.height/2);
  float mysteriousHeight = ((visiblePercentage * tvBounds.size.height) - [textView visibleRect].size.height);
  float begin = middle - (percentage*mysteriousHeight) - ([textView visibleRect].size.height/2);

  NSRect visRect = NSMakeRect(0,
                   begin*scaleFactor,
                   [theImage size].width,
                   (visiblePercentage * imgSize.height));
  [self setMinimapLinesStart:(begin/tvBounds.size.height)*numLines];
  
  visiblePartOfTextView = visRect;
}

- (void)updateViewableRange
{
  NSScrollView* sv = (NSScrollView*)[[textView superview] superview];
  float proportion = [[sv verticalScroller] knobProportion];
  float percentage = [[sv verticalScroller] floatValue];
  int numLines = [self numberOfLines];
  int numVisLines = round(numLines * proportion);
  int middleLine = round(percentage*(numLines-numVisLines)+numVisLines/2);
  NSRange range = NSMakeRange(round(middleLine-(numVisLines/2)), numVisLines);

  if (range.location+range.length > [self numberOfLines])
  {
    range.location = [self numberOfLines]-range.length;
  }

  // find out whether a vertical scroller is displayed... strangely [sv hasVeticalScroller] always returns YES
  NSClipView* clipView = (NSClipView*)[[sv subviews] objectAtIndex:0];
  if ([clipView documentVisibleRect].size.height == [textView bounds].size.height)
  {
    range.location = 0;
    range.length = numLines;
  }
  viewableRange = range;
}

- (void)drawVisRect:(NSRect)drawTo
{
  // drawing the vis rect
  [self updateViewableRange];
  NSRect bounds = [self bounds];
  float visRectHeight = viewableRange.length * pixelPerLine;
  float visRectPos;
  if ([self viewableRangeScaling] != 1.0)
  {
    float rectProportion = visRectHeight / bounds.size.height;
    NSScrollView* sv = (NSScrollView*)[[textView superview] superview];
    float percentage = [[sv verticalScroller] floatValue];
    float middle = percentage*(bounds.size.height-visRectHeight) + visRectHeight/2;
    float mysteriousHeight = (rectProportion * bounds.size.height) - visRectHeight;
    visRectPos = middle - (percentage*mysteriousHeight) - (visRectHeight/2);
    if (visRectPosBeforeScrolling != -1) {
      float scrolledPixels = (visiblePartOfTextView.origin.y - visRectPosBeforeScrolling);
      visRectPos -= scrolledPixels*(bounds.size.height/visiblePartOfTextView.size.height);
    }
  }
  else
  {
    visRectPos = (viewableRange.location*pixelPerLine);
  }

  float drawToScaling = drawTo.size.height / bounds.size.height;
  NSRect visibleHighlightRect = NSMakeRect(0,
                       visRectPos*drawToScaling,
                       drawTo.size.width-1,
                       visRectHeight*drawToScaling);

  [NSGraphicsContext saveGraphicsState];
  [[NSColor colorWithCalibratedRed:0.549 green:0.756 blue:1 alpha:0.9] set];
  [NSBezierPath setDefaultLineWidth:1];
  [NSBezierPath strokeRect:visibleHighlightRect];
  [NSGraphicsContext restoreGraphicsState];
}

- (void)drawBookmarkOnLine:(unsigned)line toRect:(NSRect)drawTo
{
  NSRect bounds = [self bounds];
  float drawToScaling = drawTo.size.height / bounds.size.height;
  line = line -  [self minimapLinesStart];
    
  NSRect visibleHighlightRect = NSMakeRect(0,
                       (pixelPerLine*line*drawToScaling),
                       drawTo.size.width-1,
                       pixelPerLine*drawToScaling);

  [NSGraphicsContext saveGraphicsState];
  [[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:0.2] set];
  [NSBezierPath setDefaultLineWidth:1];
  [NSBezierPath fillRect:visibleHighlightRect];
  [NSGraphicsContext restoreGraphicsState];
  NSLog(@"bounds: %@, viewableRange: %@, visPartt: %@", NSStringFromRect(bounds), NSStringFromRange(viewableRange), NSStringFromRect(visiblePartOfTextView));  
  //   NSLog(@"line: %i, drawTo: %@", line, NSStringFromRect(drawTo));  
  NSLog(@"asjfjabf %f , %f", (visiblePartOfTextView.origin.y / drawToScaling),pixelPerLine*drawToScaling*line);
}

#pragma mark overridden-methods
- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    unsigned int absoluteLineIdx = [self absoluteLineIdxFromPoint:mouseLoc];
    if ([windowController isSoftWrapEnabled]) {
      // we use slightly "weaker" mode: scroll by percentage then centerCaretInDisplay...
      // can not correctly select the first and last few lines of the document, because
      // it always selects the center line... but will always scroll correctly at least
      float y = absoluteLineIdx * [textView lineHeight];
      float percentage = y / [textView bounds].size.height;
      [windowController scrollToYPercentage:percentage];
    } else {
      // will select all lines correctly, but does not work in "soft wrap" mode, because
      // "absoluteLineIdx" will not really be the absolute line (wrapping can not be  
      // taken into account in the calculation)
      if (mouseDownLineIdx != absoluteLineIdx)
          [windowController selectFromLine:mouseDownLineIdx toLine:absoluteLineIdx];
      else
          [windowController scrollToLine:absoluteLineIdx];
    }
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    mouseDownLineIdx = [self absoluteLineIdxFromPoint:mouseLoc];
    if (mouseDownLineIdx > [self numberOfLines])
      mouseDownLineIdx = [self numberOfLines];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
  if (minimapIsScrollable) {
    NSRect tvBounds = [textView bounds];
    float scaleFactor = [theImage size].height / tvBounds.size.height;

    NSRect newVisRect = visiblePartOfTextView;
    if (visRectPosBeforeScrolling == -1)
      visRectPosBeforeScrolling = visiblePartOfTextView.origin.y;

    float newBegin = (newVisRect.origin.y / scaleFactor) + ([theEvent deltaY]/scaleFactor)*(-5);

    if (newBegin < 0)
      newBegin = 0;
    float lowerBound = tvBounds.size.height-(newVisRect.size.height/scaleFactor);
    if (newBegin > lowerBound)
      newBegin = lowerBound;

    newVisRect.origin.y = newBegin*scaleFactor;
    [self setMinimapLinesStart:(newBegin/tvBounds.size.height)*[self numberOfLines]];
    visiblePartOfTextView = newVisRect;
    [self setNeedsDisplay:YES];
  }
}

- (void) viewDidEndLiveResize
{
  [self refresh];
  [self setDirty:YES];
}
- (BOOL)isFlipped
{
  return YES;
}
- (BOOL)isOpaque
{
    return YES;
}


#pragma mark public API

/*
 Repaint, and also request a redraw of theImage
 */
- (void)refresh {
  requestRedraw = YES;
  visRectPosBeforeScrolling = -1;

  [self setNeedsDisplayInRect:[self visibleRect]];
}

/*
 Repaints the existing Image to the minimap-view(no drawing operation is scheduled)
 */
- (void)repaint
{
  [self setNeedsDisplayInRect:[self visibleRect]];
}

/*
 Called when the minimap is initialized for a document, similar to refresh, more initialization
 */
- (void)firstRefresh {
  firstDrawTimer = nil;
  requestRedraw = YES;
  visRectPosBeforeScrolling = -1;
  
  [self setDirty:YES];
  [self updateGutterSize];
  [updater setDirtyExceptForVisiblePart];
  
  [self setNeedsDisplayInRect:[self visibleRect]];
}

/*
 Called whenever the textview scrolls. Scrolls the minimap using the existing image
 of the whole document. no redrawing -> fluent scrolling
 */
- (void)reactToScrollingTextView {
  [self updateVisiblePartOfTextView];
  visRectPosBeforeScrolling = -1;
  [self setNeedsDisplayInRect:[self visibleRect]];
/*
  if (minimapIsScrollable) {
    NSTimer* old_timer = [self timer];
    if (old_timer != NULL && [old_timer isValid]) {
      [old_timer invalidate];
    }
    // do not refresh instantly, wait until scrolling finished
    NSTimer* t = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(refresh) userInfo:nil repeats:NO];
    [self setTimer:t];
  }
*/
}

- (void)setNewDocument
{
  [queue setSuspended:NO];
  [queue cancelAllOperations];
  [theImage release];
  theImage = NULL;
  firstDraw = YES;
  if (firstDrawTimer != nil && [firstDrawTimer isValid]) {
    [firstDrawTimer invalidate];
    firstDrawTimer = nil;
  }
}

- (void)fillWithBackground
{
  [theImage lockFocus];
    [[self currentBackgroundColor] set];
    NSRectFill(NSMakeRect(0, 0, [theImage size].width, [theImage size].height));
  [theImage unlockFocus];
}

- (NSColor*)currentBackgroundColor
{
  id stylesheet = [textView currentStyleSheet];
  NSDictionary* firstEntry = [(NSArray*)stylesheet objectAtIndex:0]; // the first entry seems to always contain the main settings
  NSString* bgColor = [[firstEntry objectForKey:@"settings"] objectForKey:@"background"];
  unsigned aValue = strtoul([[bgColor substringWithRange:NSMakeRange(1, 6)] UTF8String], NULL, 16);
  CGFloat red = ((CGFloat)((aValue & 0xFF0000) >> 16)) / 255.0f;
  CGFloat green = ((CGFloat)((aValue & 0xFF00) >> 8)) / 255.0f;
  CGFloat blue = (CGFloat)(aValue & 0xFF) / 255.0f;
  CGFloat alpha = 1.0;
  if ([bgColor length] == 9) //  if a alpha was given
  {
    unsigned alphaValue = strtoul([[bgColor substringWithRange:NSMakeRange(7, 2)] UTF8String], NULL, 16);
    alpha = (CGFloat)(alphaValue & 0xFF) / 255.0f;
  }
  return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
}

- (void)asyncDrawFinished: (NSImage*) bitmap
{
  [theImage release];
  theImage = nil;
  theImage = [bitmap retain];

  if (minimapIsScrollable && [self dirty]) {
    [updater setDirtyExceptForVisiblePart];
    [updater startRedrawInBackground];
    [self setDirty:NO];
  }

  if (minimapIsScrollable)
    pixelPerLine = [[NSUserDefaults standardUserDefaults] floatForKey:@"Minimap_scaleUpTo"];
  else
    pixelPerLine = [self bounds].size.height / [self numberOfLines];

  [self setNeedsDisplay:YES];
}

- (int)numberOfLines
{
  unsigned int lineHeight = [textView lineHeight];

  float h = [textView bounds].size.height;
  int totalLines = round(h/lineHeight);
  return totalLines;
}

#pragma mark private-methods
- (void)updateGutterSize
{
  int w = [textView bounds].size.width;
  NSBitmapImageRep* rawImg = [textView snapshotInRect:NSMakeRect(0,0,w,1)];
  NSColor* refColor = [[rawImg colorAtX:0 y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];//[self currentBackgroundColor];

  int i = 1;
  NSColor* color = [[rawImg colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  int imgWidth = [rawImg size].width;
  while ([color isEqual:refColor] && i < imgWidth) {
    i++;
    color = [[rawImg colorAtX:i y:0] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  }
  if (i == imgWidth)
    gutterSize = 0;
  else
    gutterSize = i+1;
}

-(void)initializeBookmarks
{
  NSArray* bkmarks = [windowController getBookmarks];
  [self setBookmarks:[NSMutableArray arrayWithArray:bkmarks]];
  NSLog(@"bookmarks loaded: %@", [self bookmarks]);
}

- (unsigned int)absoluteLineIdxFromPoint:(NSPoint)mouseLoc
{
    float ratio = drawnRect.size.height / [self bounds].size.height;
    unsigned int relativeLineIdx;
    if (ratio < 1.0) {
      relativeLineIdx = floor(mouseLoc.y / scaleDownTo);
    }
    else {
      relativeLineIdx = floor(mouseLoc.y / pixelPerLine);
    }
    unsigned int absoluteLineIdx = minimapLinesStart + relativeLineIdx;
    return absoluteLineIdx;
}

@end
