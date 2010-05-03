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
- (void)updateVisiblePartOfTextView;
- (NSColor*)currentBackgroundColor;
- (void)fillWithBackground;
- (void)firstRefresh;
@end

// stuff implemented by the TextMate textview
@interface NSView (MM_NSView_OnlyByOakTextView)
- (unsigned int)lineHeight;
- (id)currentStyleSheet;
@end

@implementation MinimapView

@synthesize windowController, textView, theImage, timer, 
    viewableRangeScaling, dirty, minimapLinesStart, gutterSize, visiblePartOfTextView;
//@synthesize drawLock;
  
#pragma mark init
- (id)initWithTextView:(NSView*) tv
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
  }
  return self;
}

- (void)dealloc
{
  [queue cancelAllOperations];
  [queue waitUntilAllOperationsAreFinished];
  
  [theImage release];
  [updater release];
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
  [self drawVisRect:drawTo];
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

#pragma mark overridden-methods
- (void)mouseDown:(NSEvent *)theEvent
{
    BOOL keepOn = YES;
    BOOL isInside = YES;
    NSPoint mouseLoc;
    while (keepOn) {
        theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask];
        mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        isInside = [self mouse:mouseLoc inRect:[self bounds]];
        switch ([theEvent type]) {
            case NSLeftMouseUp:
        if (isInside){
          unsigned int relativelineIdx = floor(mouseLoc.y / pixelPerLine);
          unsigned int absoluteLineIdx = minimapLinesStart+relativelineIdx;
          [windowController scrollToLine:absoluteLineIdx];
        }
        keepOn = NO;
        break;
            default:
        /* Ignore any other kind of event. */
        break;
        }

    };
    return;
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

@end
