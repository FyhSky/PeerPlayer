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
    [self.mpv stop];
    self.currentFiles = nil;
    [self.peerflix downloadTorrent:url];
}

-(void) torrentReady:(NSDictionary*)data {
    self.currentFiles = data;
    [self updateTorrentMenu];
    
    // Default action is playing the largest file.
    NSInteger maxSize = 0;
    NSString* targetHash;
    NSString* filename;
    NSArray* files = [data objectForKey:@"Files"];
    for(NSDictionary* dict in files) {
        NSInteger s = [[dict objectForKey:@"Size"] longValue];
        NSLog(@"size: %ld", s);
        if(maxSize < s) {
            maxSize = s;
            targetHash = [dict objectForKey:@"Hash"];
            filename = [dict objectForKey:@"Filename"];
        }
    }
    
    NSLog(@"Largest Filename: %@", filename);
    
    if(targetHash != nil) {
        [self.mpv playWithUrl:[self.peerflix streamUrlFromHash:targetHash]];
    }
    else {
        NSLog(@"Nothing to play");
    }
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

-(void) torrentMenuItemAction:(id) sender {
    NSDictionary* dict = [sender representedObject];
    NSString* hash = [dict objectForKey:@"Hash"];
    NSLog(@"Selected hash: %@", hash);
    [self.mpv playWithUrl:[self.peerflix streamUrlFromHash:hash]];
}


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
    
    // Initialize Mpv Controller.
    self.mpv = [[MpvController alloc] initWithWindow:self.window];
    
    [NSApp activateIgnoringOtherApps:YES];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    atexit_b(^{
        // Because activation policy has just been set to behave like a real
        // application, that policy must be reset on exit to prevent, among
        // other things, the menubar created here from remaining on screen.
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    });
    
    // Clean existing peerflix
    [Peerflix kill];
    
    // Init main window
    [self createWindow];
    self.peerflix = [[Peerflix alloc] init];
    self.peerflix.delegate = self;
    
    [self updateTorrentMenu];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    NSLog(@"new file load: %@", filename);
    [self playTorrent:filename];
    return YES;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.mpv quit];
    [Peerflix kill];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}


#pragma mark IBActions

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

@end
