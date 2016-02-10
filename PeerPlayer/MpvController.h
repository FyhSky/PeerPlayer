//
//  MpvController.h
//  PeerPlayer
//
//  Created by 문희홍 on 2016. 2. 9..
//  Copyright © 2016년 HackersTalk. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>

#import <mpv/client.h>
#import <mpv/opengl_cb.h>


@interface MpvClientOGLView : NSOpenGLView<NSDraggingDestination>
@property mpv_opengl_cb_context *mpvGL;
- (instancetype)initWithFrame:(NSRect)frame;
- (void)drawRect;
- (void)fillBlack;
@end


@interface CocoaWindow : NSWindow
@property(strong) MpvClientOGLView *glView;

- (void)initOGLView;
@end


@interface MpvController : NSObject {
    mpv_handle *mpv;
    dispatch_queue_t queue;
}

@property (strong) CocoaWindow* window;

-(id) initWithWindow:(CocoaWindow*) window;

-(void) playWithUrl:(NSString*) url;
-(void) stop;
-(void) quit;

@end