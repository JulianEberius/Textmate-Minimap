// Code inherited from Ciarán Walsh's ProjectPlus ( http://ciaranwal.sh/2008/08/05/textmate-plug-in-projectplus )

#import "MMCWTMSplitView.h"

@implementation MMCWTMSplitView
+ (NSImage*)horizontalGradientImage;
{
	static NSImage* _horizontalGradientImage=nil;
	if(_horizontalGradientImage==nil){
		UInt8 bytes[]={
		0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
		0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x02, 0x08, 0x02, 0x00, 0x00, 0x00, 0xee, 0x03, 0xda,
		0x87, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59, 0x73, 0x00, 0x00, 0x0b, 0x13, 0x00, 0x00, 0x0b,
		0x13, 0x01, 0x00, 0x9a, 0x9c, 0x18, 0x00, 0x00, 0x00, 0x23, 0x49, 0x44, 0x41, 0x54, 0x08, 0x99,
		0x63, 0x5c, 0xba, 0x74, 0x69, 0x78, 0x78, 0xf8, 0xbf, 0x7f, 0xff, 0xfe, 0xfe, 0xfd, 0xfb, 0xe7,
		0xcf, 0x9f, 0xdf, 0x48, 0xe0, 0xd8, 0xb1, 0x63, 0x4c, 0x0c, 0x78, 0x01, 0x00, 0x9d, 0xdc, 0x19,
		0xf3, 0xdb, 0x7c, 0x7c, 0x73, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60,
		0x82 };

		NSData* data=[NSData dataWithBytes:bytes length:sizeof(bytes)];
		_horizontalGradientImage=[[NSImage alloc]initWithData:data];
	}
	return _horizontalGradientImage;
}


- (void)drawDividerInRect:(NSRect)rect
{
	if([self isVertical])
	{
		NSRect fromRect;
		NSImage* image    = [MMCWTMSplitView horizontalGradientImage];
		fromRect.size     = [image size];
		fromRect.origin.x = 1;
		fromRect.origin.y = 0;
		fromRect.size.width--;

		[image drawInRect:rect fromRect:fromRect operation:NSCompositeCopy fraction:1.0];
	}
	[super drawDividerInRect:rect];
}

- (CGFloat)dividerThickness
{
    return 1.0;
}

- (BOOL)sideBarOnRight;
{
	return sidebarOnRight;
}

- (void)setSideBarOnRight:(BOOL)onRight;
{
	sidebarOnRight = onRight;
}

- (NSView*)drawerView
{
	if([self sideBarOnRight])
		return [[self subviews] objectAtIndex:1];
	else
		return [[self subviews] objectAtIndex:0];
}

- (NSView*)documentView
{
	if([self sideBarOnRight])
		return [[self subviews] objectAtIndex:0];
	else
		return [[self subviews] objectAtIndex:1];
}

#define MIN_DRAWER_VIEW_WIDTH   90
#define MIN_DOCUMENT_VIEW_WIDTH 400

- (float)minLeftWidth
{
	return [self sideBarOnRight] ? MIN_DOCUMENT_VIEW_WIDTH : MIN_DRAWER_VIEW_WIDTH;
}

- (float)minRightWidth
{
	return [self sideBarOnRight] ? MIN_DRAWER_VIEW_WIDTH : MIN_DOCUMENT_VIEW_WIDTH;
}
@end