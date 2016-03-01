//
//  AppDelegate.m
//  PeerPlayer
//
//  Created by 문희홍 on 2016. 2. 7..
//  Copyright © 2016년 HackersTalk. All rights reserved.
//

#import "AppDelegate.h"


@implementation AppDelegate

-(void) playTorrent:(NSString*) url {
    // Make sure that downloading the torrent after intializing
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mpv stop];
        self.currentFiles = nil;
        [self.peerflix downloadTorrent:url];
    });
    
}

-(void) updateTorrentMenu {
    [self.torrentMenu removeAllItems];
    NSArray* files = [self.currentFiles objectForKey:@"Files"];
    for(NSDictionary* dict in files) {
        NSString* filename = [dict objectForKey:@"Filename"];
        
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:filename
                                                      action:@selector(torrentMenuItemAction:)
                                               keyEquivalent:@""];
        item.representedObject = dict;
        [self.torrentMenu addItem:item];
    }
}

-(void) updateTorrentMenuState {
    NSString* hash = [self.selectedFile objectForKey:@"Hash"];
    for(NSMenuItem* item in self.torrentMenu.itemArray) {
        NSDictionary* d = item.representedObject;
        if([[d objectForKey:@"Hash"] isEqualToString:hash]) {
            [item setState:NSOnState];
        }
        else {
            [item setState:NSOffState];
        }
        
    }
}

#pragma mark Peerflix Delegate


-(void) torrentReady:(NSDictionary*)data {
    self.currentFiles = data;
    [self updateTorrentMenu];
    
    // Default action is playing the largest file.
    NSInteger maxSize = 0;
    NSDictionary* targetFile;
    NSString* targetHash;
    NSString* filename;
    NSArray* files = [data objectForKey:@"Files"];
    for(NSDictionary* dict in files) {
        NSInteger s = [[dict objectForKey:@"Size"] longValue];
        if(maxSize < s) {
            maxSize = s;
            targetHash = [dict objectForKey:@"Hash"];
            filename = [dict objectForKey:@"Filename"];
            targetFile = dict;
        }
    }
    
    NSLog(@"Largest Filename: %@", filename);
    
    if(targetHash != nil) {
        NSString* url = [self.peerflix streamUrlFromHash:targetHash];
        NSLog(@"URL: %@", url);
        [self.mpv playWithUrl:url];
        self.selectedFile = targetFile;
        [self updateTorrentMenuState];
    }
    else {
        NSLog(@"Nothing to play");
    }
}


-(void) torrentStatusChanged:(NSDictionary*) info {
    [[NSNotificationCenter defaultCenter] postNotificationName:kPPTorrentStatusChanged
                                                        object:self
                                                      userInfo:info];
}


#pragma mark Player Delegate

-(void) playInfoChanged:(PlayInfo *)info {
    [[NSNotificationCenter defaultCenter] postNotificationName:kPPPlayInfoChanged
                                                        object:self
                                                      userInfo:[NSDictionary dictionaryWithObject:info forKey:kPPPlayInfoKey]];

}

#pragma mark App Delegate

-(void) createWindow {
    // Style the window and prepare for mpv player.
    int mask = NSTitledWindowMask|NSClosableWindowMask|
    NSMiniaturizableWindowMask|NSResizableWindowMask|
    NSFullSizeContentViewWindowMask|NSUnifiedTitleAndToolbarWindowMask;
    
    [self.window setStyleMask:mask];
    [self.window setMinSize:NSMakeSize(200, 200)];
    [self.window initOGLView];
    [self.window setStyleMask:mask];
    [self.window setBackgroundColor:
     [NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:1.f]];
    [self.window makeMainWindow];
    [self.window makeKeyAndOrderFront:nil];
    [self.window setMovableByWindowBackground:YES];
    [self.window setTitlebarAppearsTransparent:YES];
    [self.window setTitleVisibility:NSWindowTitleHidden];
    [self.window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
    
    [NSApp activateIgnoringOtherApps:YES];
}

-(void) initApp {
    if(self.initialized) {
        return;
    }
    self.initialized = YES;
    
    NSLog(@"Init PeerPlayer");
    
    // Init main window
    [self createWindow];
    [self updateTorrentMenu];
    
    // Register magnet link if possible
    if(![self registerMagnet]){
        NSLog(@"Failed to associate the magnet url scheme as default.");
    }
    
    // Initialize Mpv Controller.
    self.mpv = [[MpvController alloc] initWithWindow:self.window];
    self.mpv.delegate = self;
    
    // Avoid main thread blocking
    dispatch_async(dispatch_get_main_queue(), ^{
        // Initialize Peerflix
        self.peerflix = [[Peerflix alloc] init];
        self.peerflix.delegate = self;
        [self.peerflix initialize];
    });
}

-(BOOL) registerMagnet {
    // Register magnet scheme as default
    CFStringRef bundleID = (__bridge CFStringRef)[[NSBundle mainBundle] bundleIdentifier];
    OSStatus ret = LSSetDefaultHandlerForURLScheme(CFSTR("magnet"), bundleID);
    return ret == noErr;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[NSAppleEventManager sharedAppleEventManager]
     setEventHandler:self
     andSelector:@selector(handleURLEvent:withReplyEvent:)
     forEventClass:kInternetEventClass
     andEventID:kAEGetURL];
    
    [self initApp];
}

- (void)handleURLEvent:(NSAppleEventDescriptor*)event
        withReplyEvent:(NSAppleEventDescriptor*)replyEvent
{
    NSString* url = [[event paramDescriptorForKeyword:keyDirectObject]
                     stringValue];
    NSLog(@"handle URL: %@", url);
    [self initApp];
    [self playTorrent:url];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    NSLog(@"new file load: %@", filename);
    [self initApp];
    [self playTorrent:filename];
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.mpv quit];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}


#pragma mark IBActions


-(void) torrentMenuItemAction:(id) sender {
    NSDictionary* dict = [sender representedObject];
    NSString* hash = [dict objectForKey:@"Hash"];
    NSString* filename = [dict objectForKey:@"Filename"];
    NSLog(@"Selected hash: %@", hash);
    
    NSString* ext = [filename pathExtension];
    if([ext isEqualToString:@"smi"] || [ext isEqualToString:@"srt"]) {
        if(!self.mpv.info.loadFile) {
            NSLog(@"Skip this subtitle. No playback is playing.");
            return;
        }
        
        // Load subtitle asynchronously
        NSURLSession * session = [NSURLSession sharedSession];
        
        NSURL* url = [NSURL URLWithString:[self.peerflix streamUrlFromHash:hash]];
        NSLog(@"Subtitle url: %@", url);
        
        NSURLSessionDataTask * dataTask =
        [session dataTaskWithURL:url
               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
         {
             if(error != nil) {
                 NSLog(@"Failed to load subtitle: %@", error);
             }
             else {
                 NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
                 NSLog(@"Temporary subtitle path: %@", path);
                 if([data writeToFile:path atomically:YES]) {
                     [self.mpv loadSubtitle:path];
                 }
                 else {
                     NSLog(@"Failed to save subtitle: %@", error);
                 }
             }
         }];
        
        [dataTask resume];

    }
    else {
        // Play file
        [self.mpv playWithUrl:[self.peerflix streamUrlFromHash:hash]];
        self.selectedFile = dict;
        [self updateTorrentMenuState];
    }
    
}


-(IBAction) openTorrentFile:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setResolvesAliases:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanCreateDirectories:NO];
    [openPanel setTitle:@"Open Torrent File"];
    
    if ([openPanel runModal] == NSFileHandlingPanelOKButton) {
        NSString *fileUrl = [[[openPanel URLs] objectAtIndex:0] path];
        NSLog(@"file selected: %@", fileUrl);
        [self playTorrent:fileUrl];
    }

}

-(IBAction) stopCurrentVideo:(id)sender {
    [self.mpv stop];
}

@end
