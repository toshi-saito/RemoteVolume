//
//  Volume.m
//  RemoteVolume
//
//  Created by toshiyuki on 2015/12/22.
//  Copyright © 2015年 toshiyuki. All rights reserved.
//

#import "Volume.h"
#import <MediaPlayer/MediaPlayer.h>

@implementation Volume

+(double) get {
    MPMusicPlayerController *playerController = [MPMusicPlayerController systemMusicPlayer];
    id val = [playerController valueForKey: @"volume"];
    return [val floatValue];
}

+ (void) set:(double) volume {
    MPMusicPlayerController *playerController = [MPMusicPlayerController systemMusicPlayer];
    [playerController setValue:@(volume) forKey:@"volume"];
    [playerController setValue:@(volume) forKey:@"volumePrivate"];
}

@end
