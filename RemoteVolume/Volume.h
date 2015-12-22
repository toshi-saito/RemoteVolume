//
//  Volume.h
//  RemoteVolume
//
//  Created by toshiyuki on 2015/12/22.
//  Copyright © 2015年 toshiyuki. All rights reserved.
//

#ifndef Volume_h
#define Volume_h

#import <Foundation/Foundation.h>

@interface Volume : NSObject
+ (double) get;
+ (void) set:(double) volume;
@end


#endif /* Volume_h */
