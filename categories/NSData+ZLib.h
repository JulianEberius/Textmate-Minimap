//
//  NSData+ZLib.h
//  Textmate-Minimap
//
//  Copied from CocoaDev: http://www.cocoadev.com/index.pl?NSDataCategory

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>


@interface NSData (NSDataExtension)
  - (NSData *) zlibInflate;
  - (NSData *) zlibDeflate;
@end
