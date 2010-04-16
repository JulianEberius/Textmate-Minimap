// Code inherited from Ciarán Walsh's ProjectPlus ( http://ciaranwal.sh/2008/08/05/textmate-plug-in-projectplus )

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