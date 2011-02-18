//
//  NSData+ZLib.h
//  Textmate-Minimap
//
//  Created by Julian Eberius on 17.02.11.
//  Copyright 2011 none. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>


@interface NSData (NSDataExtension)
  - (NSData *) zlibInflate;
  - (NSData *) zlibDeflate;

@end
