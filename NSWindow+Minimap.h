//
//  NSWindow+Minimap.h
//  TextmateMinimap
//
//  Created by Julian Eberius on 09.02.10.
//  Copyright 2010 Julian Eberius. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSWindow (MM_NSWindow)
// called when the user switches tabs (or load files)
- (void)MM_setRepresentedFilename:(NSString*)aPath;
// called when a document change state (e.g. when saved to disk)
- (void)MM_setDocumentEdited:(BOOL)flag;
- (void)MM_becomeMainWindow;
@end
