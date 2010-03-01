//
//  SUAppcast.h
//  Sparkle
//
//  Created by Andy Matuschak on 3/12/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//

#ifndef SUAPPCAST_H
#define SUAPPCAST_H

@class MMSUAppcastItem;
@interface MMSUAppcast : NSObject
{
@private
	NSArray *items;
	NSString *userAgentString;
	id delegate;
	NSString *downloadFilename;
	NSURLDownload *download;
}

- (void)fetchAppcastFromURL:(NSURL *)url;
- (void)setDelegate:delegate;
- (void)setUserAgentString:(NSString *)userAgentString;

- (NSArray *)items;

@end

@interface NSObject (SUAppcastDelegate)
- (void)appcastDidFinishLoading:(MMSUAppcast *)appcast;
- (void)appcast:(MMSUAppcast *)appcast failedToLoadWithError:(NSError *)error;
@end

#endif
