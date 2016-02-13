//
//  Peerflix.h
//  PeerPlayer
//
//  Created by 문희홍 on 2016. 2. 9..
//  Copyright © 2016년 HackersTalk. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PeerflixDelegate <NSObject>

-(void) torrentReady:(NSDictionary*)data;

@end




@interface Peerflix : NSObject

@property (strong) id<PeerflixDelegate> delegate;

-(void) initialize;

// Download torrent file
-(void) downloadTorrent:(NSString*)pathOrMagnet;

// Get stream url from file hash.
-(NSString*) streamUrlFromHash:(NSString*) hash;

@end
