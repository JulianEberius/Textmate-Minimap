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