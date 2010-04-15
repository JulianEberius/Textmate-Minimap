#import "MMKFSplitView.h"
@class CWTMSplitView;

@interface MMCWTMSplitView : MMKFSplitView
{
	BOOL sidebarOnRight;
}
- (BOOL)sideBarOnRight;
- (void)setSideBarOnRight:(BOOL)onRight;

- (NSView*)drawerView;
- (NSView*)documentView;

- (float)minLeftWidth;
- (float)minRightWidth;
@end

/* we have to change some of projectplus' methods 
 to make it compatible with splitviews in splitviews*/
@interface NSSplitView(projectplus)
- (NSView*)MM_drawerView;
- (NSView*)MM_documentView;
@end
