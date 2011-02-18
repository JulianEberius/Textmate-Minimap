//
//  NSWindowController+Minimap.m
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import "NSWindowController+Minimap.h"
#import "MinimapView.h"
#import "TextMate.h"
#import "NSView+Minimap.h"
#import "TextMateMinimap.h"
#import "objc/runtime.h"
#import "MMCWTMSplitView.h"
#import "NSData+ZLib.h"
#include "sys/xattr.h"
#include "math.h"


// stuff that the textmate-windowcontrollers (OakProjectController, OakDocumentControler) implement
@interface NSWindowController (TextMate_WindowControllers_Only)
- (id)textView;
- (void)goToLineNumber:(id)newLine;
- (unsigned int)getLineHeight;
// that is only implemented by OakProjectController
- (NSString*)filename;
@end

//stuff that textmate's textview implements
@interface NSView (TextMate_OakTextView_Only)
- (id)currentStyleSheet;
- (BOOL)storedSoftWrapSetting;
- (void)centerCaretInDisplay:(id)sender;
- (void)scrollViewByX:(float)x byY:(long)y;
@end

@interface NSWindowController (Private_MM_NSWindowController)
- (NSRectEdge) getCorrectMinimapDrawerSide;
- (BOOL)shouldOpenMinimapDrawer:(NSString*)filename;
- (void)writeMinimapOpenStateToFileAttributes:(NSString*)filename;
- (NSRectEdge)getPreferableWindowSide;
- (BOOL)isInSidepaneMode;
- (BOOL)sidepaneIsClosed;
- (void)setSidepaneIsClosed:(BOOL)closed;
- (void)adaptWindowSize;
@end

// id for saving extended file attributes
const char* MINIMAP_STATE_ATTRIBUTE_UID = "textmate.minimap.state";
const char* TM_BOOKMARKED_LINES_UID = "com.macromates.bookmarked_lines";

@implementation NSWindowController (MM_NSWindowController)
#pragma mark public-methods
/*
 Request a redraw of the minimap
 */
- (void)refreshMinimap
{
  MinimapView* minimapView = [self getMinimapView];
  [minimapView refresh];
}

/*
 Get the currently selected line in the TextView, tip from TM plugin mailing list
 */
- (int)getCurrentLine:(id)textView
{
  NSMutableDictionary* dict = [NSMutableDictionary dictionary];
  [textView bind:@"lineNumber" toObject:dict
     withKeyPath:@"line"   options:nil];
  int line = [(NSNumber*)[dict objectForKey:@"line"] intValue];
  return line;
}

/*
 Open / close the minimap drawer
 */
- (void)toggleMinimap
{
  
  if ([self minimapContainerIsOpen])
    [self setMinimapContainerIsOpen:NO];
  else {
    //if not in sidepane mode, do the "push the window away"-trick that the project drawer does
    [self adaptWindowSize];
    [self setMinimapContainerIsOpen:YES];
  }
  // ok, this is not scrolling, but the reaction is the same
  if ([self isInSidepaneMode])
    [[self getMinimapView] reactToScrollingTextView];
}


/*
 Call TextMate's gotoLine function
 */
- (void)scrollToLine:(unsigned int)newLine
{
  id textView = [self textView];
  MinimapView* minimapView = [self getMinimapView];
  [textView goToLineNumber: [NSNumber numberWithInt:newLine]];
  [minimapView refresh];
}

- (void)selectFromLine:(unsigned int)fromLine toLine:(unsigned int)toLine
{
  id textView = [self textView];
  MinimapView* minimapView = [self getMinimapView];

  SEL selectionModifier;
  if (toLine>fromLine)
    selectionModifier = @selector(moveDownAndModifySelection:);
  else {
    selectionModifier = @selector(moveUpAndModifySelection:);
    if (fromLine == [minimapView numberOfLines]) {
      toLine += 2;
    } else {
      fromLine += 1; toLine += 1;
    }
  }
  
  [textView goToLineNumber: [NSNumber numberWithInt:fromLine]];
  
  int i;
  for(i = 0; i <= (abs(toLine-fromLine)); ++i)
    [self performSelector:selectionModifier withObject:nil];
  
  [minimapView refresh];
}


- (void)scrollToYPercentage:(float)percentage 
{
  id textView = [self textView];
  float y = ([textView bounds].size.height * percentage)
            - ([textView visibleRect].size.height / 2);
  /* for some reason, a simple scrollPoint or scrollRectToVisible do not work */
  //[textView scrollPoint: NSMakePoint(0, y)];
  if (y < 0.0)
    y = 0.0;
  if (y + [textView visibleRect].size.height > [textView bounds].size.height)
    y =  [textView bounds].size.height - [textView visibleRect].size.height;
  
  float diff = y - [textView visibleRect].origin.y;
  NSLog(@"y: %f diff: %f", y, diff);
  [textView scrollViewByX:0 byY:diff];
  [textView centerCaretInDisplay:self];
}

/*
 Find out whether soft wrap is enabled
 */
- (BOOL)isSoftWrapEnabled
{
  return [[[self getMinimapView] textView] storedSoftWrapSetting];
}

- (void)updateTrailingSpace
{
  if (![self isInSidepaneMode]) {
    NSDrawer* drawer = [self getMinimapDrawer];
    [drawer setTrailingOffset:[self isSoftWrapEnabled] ? 40 : 56];
  }
}

#pragma mark swizzled_methods
/*
 Swizzled method: on close
 - release  minimapDrawer
 - set lastWindowController to nil
 - save minimap state to file
 */
- (void)MM_windowWillClose:(id)aNotification
{
  //save minimapstate to extended file attribute
  NSString* filename = nil;
  if ([[self className] isEqualToString:@"OakProjectController"])
    filename = [self filename];
  else
    filename = [[[self textView] document] filename];
  if (filename != nil)
    [self writeMinimapOpenStateToFileAttributes:filename];

  NSDrawer* drawer = [self getMinimapDrawer];
  [drawer setContentView:nil];
  [drawer setParentWindow:nil];
  [[TextmateMinimap instance] setLastWindowController:nil];
  [[TextmateMinimap instance] releaseIVarsFor:self];
  // call original
  [self MM_windowWillClose:aNotification];
}

/*
 Swizzled Method: called when an project or document window was openened
 - set the "lastWindowController" (top most window as seen by the plugin)
 - create a drawer for the minimap and set it's side
 - OR create sidepane
 - set the correct offsets for the minimap (different for document and project controller)
 - OR but the splitviews in the correct order
 - store references and mode in "iVars"
 
 Sorry this got quite long, but at least it's documented ;-)
 */
- (void)MM_windowDidLoad
{
  // call original
  [self MM_windowDidLoad];
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  
  [[TextmateMinimap instance] setLastWindowController:self];
  NSWindow* window=[self window];
  NSSize contentSize = NSMakeSize(160, [window frame].size.height);
  // init minimapView
  MinimapView* minimapView = [[MinimapView alloc] initWithTextView:[self textView] andWindowController:self];
  //[minimapView setWindowController:self];
  NSMutableDictionary* ivars = [[TextmateMinimap instance] getIVarsFor:self];
  NSString* filename = nil;
  
  ////////////////
  // SIDEPANE-MODE
  ////////////////
  if ([defaults boolForKey:@"Minimap_showInSidepane"]) {
    [ivars setObject:[NSNumber numberWithBool:YES]  forKey:@"minimapSidepaneModeOn"];
    NSRectEdge edge = [self getCorrectMinimapDrawerSide];
    NSView* documentView = [[window contentView] retain];
    MMCWTMSplitView* splitView;
    // check whether projectplus or missingdrawer is present
    // if so, but our splitview into their splitview, not to confuse their implementation
    // (which sadly does [window contentView] to find it's own splitView)
    if (NSClassFromString(@"CWTMSplitView") != nil 
        && [[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlus Sidebar Enabled"]
        && [self isKindOfClass:OakProjectController]) {
      
      NSView* preExistingSplitView = documentView;
      BOOL ppSidebarIsOnRight = [[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlus Sidebar on Right"];
      
      NSView* realDocumentView;
      NSView* originalSidePane;
      if (ppSidebarIsOnRight) {
        realDocumentView = [[preExistingSplitView subviews] objectAtIndex:0];
        originalSidePane = [[preExistingSplitView subviews] objectAtIndex:1];
      }
      else {
        realDocumentView = [[preExistingSplitView subviews] objectAtIndex:1];
        originalSidePane = [[preExistingSplitView subviews] objectAtIndex:0];
      }
      
      [realDocumentView retain];[realDocumentView removeFromSuperview];
      [originalSidePane retain];[originalSidePane removeFromSuperview];
      
      splitView = [[MMCWTMSplitView alloc] initWithFrame:[realDocumentView frame]];
      [splitView setVertical:YES];
      [splitView setDelegate:[TextmateMinimap instance]];
      Boolean sidebarOnRight = (edge==NSMaxXEdge);
      [splitView setSideBarOnRight:sidebarOnRight];
      
      if(!sidebarOnRight)
        [splitView addSubview:minimapView];
      [splitView addSubview:realDocumentView];
      if(sidebarOnRight)
        [splitView addSubview:minimapView];
      
      if (ppSidebarIsOnRight)
        [preExistingSplitView addSubview:splitView];
      [preExistingSplitView addSubview:originalSidePane];
      if (!ppSidebarIsOnRight)
        [preExistingSplitView addSubview:splitView];    
      [realDocumentView release];
      [originalSidePane release];
    }
    // no relevant plugins present, init in contentView of Window
    else {
      [window setContentView:nil];
      
      splitView = [[MMCWTMSplitView alloc] initWithFrame:[documentView frame]];
      [splitView setVertical:YES];
      [splitView setDelegate:[TextmateMinimap instance]];
      Boolean sidebarOnRight = (edge==NSMaxXEdge);
      [splitView setSideBarOnRight:sidebarOnRight];
      
      if(!sidebarOnRight)
        [splitView addSubview:minimapView];
      [splitView addSubview:documentView];
      if(sidebarOnRight)
        [splitView addSubview:minimapView];
      
      [window setContentView:splitView];
    }
    
    [[splitView drawerView] setFrameSize:contentSize];
    
    if ([[self className] isEqualToString:@"OakProjectController"]) {
      filename = [self filename];
    }
    else if ([[self className] isEqualToString:@"OakDocumentController"]) {
      filename = [[[self textView] document] filename];
    }
    [ivars setObject:splitView forKey:@"minimapSplitView"];
    BOOL shouldOpen = [self shouldOpenMinimapDrawer:filename];
    [self setMinimapContainerIsOpen:shouldOpen];
      
    [[NSUserDefaults standardUserDefaults] setBool:shouldOpen forKey:@"Minimap_lastDocumentHadMinimapOpen"];
    
    [splitView release];
    [documentView release];
  }
  //////////////
  //DRAWER MODE
  //////////////
  else {
    NSRectEdge edge = [self getCorrectMinimapDrawerSide];
    id minimapDrawer = [[NSDrawer alloc] initWithContentSize:contentSize preferredEdge:edge];
    
    [minimapDrawer setParentWindow:window];
    [minimapDrawer setContentView:minimapView];
    
    int trailingOffset = [self isSoftWrapEnabled] ? 40 : 56;
    if ([[self className] isEqualToString:@"OakProjectController"]) {
      [minimapDrawer setTrailingOffset:trailingOffset];
      [minimapDrawer setLeadingOffset:24];
      filename = [self filename];
    }
    else if ([[self className] isEqualToString:@"OakDocumentController"]) {
      [minimapDrawer setTrailingOffset:trailingOffset];
      [minimapDrawer setLeadingOffset:0];
      filename = [[[self textView] document] filename];
    }
    [ivars setObject:minimapDrawer forKey:@"minimapDrawer"];
    BOOL shouldOpen = [self shouldOpenMinimapDrawer:filename];
    if (shouldOpen)
      [minimapDrawer openOnEdge:edge];
    [[NSUserDefaults standardUserDefaults] setBool:shouldOpen forKey:@"Minimap_lastDocumentHadMinimapOpen"];
    [minimapDrawer release];
    [ivars setObject:[NSNumber numberWithBool:NO]  forKey:@"minimapSidepaneModeOn"];
  }
  
  [ivars setObject:minimapView forKey:@"minimap"];
  [minimapView release];
}

/*
 Swizzled method: called when the project drawer is opened or closed
 */
- (void)MM_toggleGroupsAndFilesDrawer:(id)sender
{
  [self MM_toggleGroupsAndFilesDrawer:sender];
  
  // if the minimap is open, we might need to make some room on the screen
  if ([self minimapContainerIsOpen])
    [self adaptWindowSize];
  // if auto-mode is set, we need to check whether both drawers are now on the same side, in which case we need to
  // close the minimap and reopen it on the other side
  if ([[NSUserDefaults standardUserDefaults] integerForKey:@"Minimap_minimapSide"] == MinimapAutoSide) {
    // the following code is quite ugly... well it works for now :-)
    NSDrawer* projectDrawer = nil;
    for (NSDrawer *drawer in [[self window] drawers])
      if (! [[drawer contentView] isKindOfClass:[MinimapView class]])
        projectDrawer = drawer;
        
    // if no drawer is found, we're running ProjectPlus or MissingDrawer...
    // if we're in sidepane mode, this is all irrelephant(http://irrelephant.net/)
    if (projectDrawer == nil || [self isInSidepaneMode]) {
      return;
    }
    // the regular old case: both are drawers!
    NSDrawer* minimapDrawer = [self getMinimapDrawer];
    if ([minimapDrawer state] == NSDrawerClosedState || [minimapDrawer state] == NSDrawerClosingState)
      return;
    
    int projectDrawerState = [projectDrawer state];
    if ((projectDrawerState == NSDrawerOpeningState) || (projectDrawerState == NSDrawerOpenState))
    {
      if ([projectDrawer edge] == [minimapDrawer edge])
      {
        [minimapDrawer close];
        [[NSNotificationCenter defaultCenter] addObserver:self
                             selector:@selector(reopenMinimapDrawer:)
                               name:NSDrawerDidCloseNotification object:minimapDrawer];
      }
    }
  }
  // if we an projectplus are both in sidepane-mode, toggling the drawer must also tog
  // gle a special repaint of the map (similar to scrolling)
  if ([self isInSidepaneMode]
      && [[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlus Sidebar Enabled"]) {
    [[self getMinimapView] reactToScrollingTextView];
  }
}

-(void)MM_PrefWindowWillClose:(id)arg1
{
  [self MM_PrefWindowWillClose:arg1];
  [[[TextmateMinimap instance] lastWindowController] refreshMinimap];
}

#pragma mark private

/*
  private: will change the windows size if the minimap is open(ed) and would not fit on the screen
  */
- (void)adaptWindowSize
{
  if (![self isInSidepaneMode]) {
    // assemble a bunch of widths and positions
    NSRect screenFrame = [[[self window] screen] frame];
    int fullWidth = 0;
    
    fullWidth += [[self getMinimapView] frame].size.width+11;
    NSRect windowFrame = [[self window] frame];
    fullWidth += windowFrame.size.width;
    for (NSDrawer *drawer in [[self window] drawers])
      if (! [[drawer contentView] isKindOfClass:[MinimapView class]])
        if ([drawer state] == NSDrawerOpenState || [drawer state] == NSDrawerOpeningState)
          fullWidth += [[drawer contentView] frame].size.width+11;
    
    if (fullWidth > screenFrame.size.width) {
      //we need to scale the window...
      int diff = fullWidth - screenFrame.size.width;
      NSRect newWindowFrame;
      if ([self getCorrectMinimapDrawerSide] == NSMaxXEdge)
        newWindowFrame = NSMakeRect(windowFrame.origin.x, windowFrame.origin.y,
                                  windowFrame.size.width-diff, windowFrame.size.height);
      else
        newWindowFrame = NSMakeRect(windowFrame.origin.x+diff, windowFrame.origin.y,
                                  windowFrame.size.width-diff, windowFrame.size.height);
      [[self window] setFrame:newWindowFrame display:YES animate:YES];
    }
  }
}


/*
  Finds out whether the minimap container is open or closed. This abstracts the opened and closed methods
  for the sidepane and the minimap, calling whichever variant is activated.
*/
- (BOOL)minimapContainerIsOpen {
  if ([self isInSidepaneMode]) {
    return ![self sidepaneIsClosed];
  } 
  else {
    NSDrawer* drawer = [self getMinimapDrawer];
    int state = [drawer state];
    return ((state == NSDrawerOpeningState) || (state == NSDrawerOpenState));
  }
}

/*
  Set whether the minimap container is open or closed. This abstracts the open and close methods
  for the sidepane and the minimap, calling whichever variant is activated.
*/
- (void)setMinimapContainerIsOpen:(BOOL)open {
  if (!open) {
    if ([self isInSidepaneMode]) {
      [self setSidepaneIsClosed:!open];
    } 
    else {
        [[self getMinimapDrawer] close];
    }  
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"Minimap_lastDocumentHadMinimapOpen"];
  }
  else {
    if ([self isInSidepaneMode]) {
      [self setSidepaneIsClosed:!open];
    } 
    else {
        NSRectEdge edge = [self getCorrectMinimapDrawerSide];
        [[self getMinimapDrawer] openOnEdge:edge];
    }
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"Minimap_lastDocumentHadMinimapOpen"];
  }
}

- (BOOL)isInSidepaneMode {
  NSMutableDictionary* ivars = [[TextmateMinimap instance] getIVarsFor:self];
  return [[ivars objectForKey:@"minimapSidepaneModeOn"] boolValue];
}

/*
  do not call directly! use minimapContainerIsOpen
  */
- (BOOL)sidepaneIsClosed
{
  NSMutableDictionary* ivars = [[TextmateMinimap instance] getIVarsFor:self];
  MMCWTMSplitView* splitView = (MMCWTMSplitView*)[ivars objectForKey:@"minimapSplitView"];
  return [splitView isSubviewCollapsed:[splitView drawerView]];
}

/*
  do not call directly! use setMinimapContainerIsOpen
  */
- (void)setSidepaneIsClosed:(BOOL)closed
{
  NSMutableDictionary* ivars = [[TextmateMinimap instance] getIVarsFor:self];
  MMCWTMSplitView* splitView = (MMCWTMSplitView*)[ivars objectForKey:@"minimapSplitView"];
  [splitView setSubview:[splitView drawerView] isCollapsed:closed];
  [splitView resizeSubviewsWithOldSize:[splitView bounds].size];
}

/*
 Get this window's minimap
 */
- (MinimapView*) getMinimapView
{
  NSMutableDictionary* ivars = [[TextmateMinimap instance] getIVarsFor:self];
  return (MinimapView*)[ivars objectForKey:@"minimap"];
}

/*
  Get the NSDrawer the Minimap is in. Can return nil if there is no drawer (e.g. if sidepane mode enabled)
*/
- (NSDrawer*) getMinimapDrawer
{
  NSMutableDictionary* ivars = [[TextmateMinimap instance] getIVarsFor:self];
  return (NSDrawer*)[ivars objectForKey:@"minimapDrawer"];
}

/*
  Finds out whether the minimap should be opened by looking at the following criteria:
  - the open/new document prefs the user has set
  - the file attribtues that were set for the doc or the project
*/
- (BOOL) shouldOpenMinimapDrawer:(NSString*)filename
{
  BOOL result = YES;
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  int openBehaviour = [defaults integerForKey:@"Minimap_openDocumentBehaviour"];
  int newDocBehaviour = [defaults integerForKey:@"Minimap_newDocumentBehaviour"];

  // check the extended file attributes
  char value;
  int success = getxattr([filename UTF8String], MINIMAP_STATE_ATTRIBUTE_UID, &value, 1, 0, 0);

  // if there it is a new file || the openBehaviour is the same as for new files || the extended-file-attribute isn't set
  if ((filename == nil) || (openBehaviour == MinimapAsNewDocument) || success == -1) {
    switch (newDocBehaviour) {
      default:
      case MinimapInheritShow:
        result = [defaults boolForKey:@"Minimap_lastDocumentHadMinimapOpen"];
        break;
      case MinimapAlwaysShow:
        result = YES;
        break;
      case MinimapNeverShow:
        result = NO;
        break;
    }
  }
  else if (success == 1) {
    if (value==0x31) {
      result = YES;
    } else if (value==0x30) {
      result = NO;
    }
  }
  return result;
}


- (NSArray*)getBookmarks
{
    NSString* filename = [[[self textView] document] filename];
        
    NSMutableArray* result;
    
    int value_size = getxattr([filename UTF8String], TM_BOOKMARKED_LINES_UID, NULL, 1, 0, 0);
    char value[value_size];
    int success = getxattr([filename UTF8String], TM_BOOKMARKED_LINES_UID, &value, value_size, 0, 0);
    NSData* data;  
    NSData* rawData = [NSData dataWithBytes:value length:value_size];
    if (success >= 0) {
      NSData* uncompressedData = [rawData zlibInflate];
      if (uncompressedData)
        data = uncompressedData;
      else 
        data = rawData;

      NSString* bookmarkString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
      NSString* filteredString = [self filterCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789,"] fromString:bookmarkString];
      NSArray* bookmarksStrings = [filteredString componentsSeparatedByString:@","];
      result = [NSMutableArray arrayWithArray:[bookmarksStrings valueForKey:@"intValue"]];
    } else {
      result = [NSMutableArray arrayWithCapacity:5];
    }
    return result; 
}

- (NSString*)filterCharacterSet:(NSCharacterSet*)characterSet fromString:(NSString*)input 
{
  NSMutableString *strippedString = [NSMutableString 
                                     stringWithCapacity:input.length];
  
  NSScanner *scanner = [NSScanner scannerWithString:input];
  
  while ([scanner isAtEnd] == NO) {
    NSString *buffer;
    if ([scanner scanCharactersFromSet:characterSet intoString:&buffer]) {
      [strippedString appendString:buffer];
      
    } else {
      [scanner setScanLocation:([scanner scanLocation] + 1)];
    }
  }
  return strippedString;
}

/*
 Private method: Saves the open state of the minimap into the extended file attributes
 */
- (void)writeMinimapOpenStateToFileAttributes:(NSString*)filename
{
  char value;
  if ([self minimapContainerIsOpen])
    value = 0x31; // xattr (on terminal) reads the extended file attributes as utf8 strings, this is the utf8 "1"
  else
    value = 0x30; // this is the "0"
  setxattr([filename UTF8String], MINIMAP_STATE_ATTRIBUTE_UID, &value, 1, 0, 0);
}

/*
 Private method: called by NSNotificationCenter when the minimapDrawer sends "DidClose"
 reopen minimapDrawer on the opposite side
 */
- (void)reopenMinimapDrawer:(NSNotification *)notification
{
  NSDrawer* drawer = [self getMinimapDrawer];
  if ([drawer edge] == NSMaxXEdge)
    [drawer openOnEdge:NSMinXEdge];
  else
    [drawer openOnEdge:NSMaxXEdge];

  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSDrawerDidCloseNotification object:drawer];
}

/*
 Find out on which side the minimap drawer should appear
 */
- (NSRectEdge) getCorrectMinimapDrawerSide
{
  int result;
  NSRectEdge projectDrawerSide = NSMaxXEdge;
  Boolean projectDrawerIsOpen = NO;
  Boolean projectDrawerWasFound = NO;
  for (NSDrawer *drawer in [[self window] drawers])
    if (! [[drawer contentView] isKindOfClass:[MinimapView class]]) {
      projectDrawerWasFound = YES;
      projectDrawerSide = [drawer edge];
      projectDrawerIsOpen = ([drawer state] == NSDrawerOpeningState) 
                        || ([drawer state] == NSDrawerOpenState);
    }
  switch ([[NSUserDefaults standardUserDefaults] integerForKey:@"Minimap_minimapSide"]) {
    default:
    case MinimapAutoSide:
      // in sidepane mode, the correct side is always right... except for the ProjectPlus on Right case
      if ([self isInSidepaneMode]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlus Sidebar on Right"])
          return NSMinXEdge;
        return NSMaxXEdge;
      }
      
      if (projectDrawerWasFound) {
        if (projectDrawerSide == NSMaxXEdge)
          if (projectDrawerIsOpen) result = NSMinXEdge;
          else result = NSMaxXEdge;
        else
          if (projectDrawerIsOpen) result = NSMaxXEdge;
          else result = NSMinXEdge;
      }
      // there is no project drawer we can use for orientation...
      else {
        result = [self getPreferableWindowSide];
      }
      break;

    case MinimapLeftSide:
      result = NSMinXEdge;
      break;
    case MinimapRightSide:
      result = NSMaxXEdge;
      break;
  }

  return result;
}

/*
  private method: finds the side of the window with more space to the screen's edge
*/
- (NSRectEdge)getPreferableWindowSide 
{
  NSRectEdge result = NSMaxXEdge;
  // the preferable side is where more screen space is left
  NSWindow* window = [self window];
  NSRect windowFrame = [window frame];
  if ((windowFrame.origin.x) > ([[window screen] frame].size.width - (windowFrame.origin.x+windowFrame.size.width)))
    result = NSMinXEdge;
    
  return result;
}

@end