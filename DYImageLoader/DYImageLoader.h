//
//  DYImageLoader.h
//  DYImageLoader
//
//  Created by Apple on 2019/3/15.
//  Copyright © 2019 Young. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DYImageLoader : NSObject
@property(class, atomic, readonly, strong) DYImageLoader* sharedImageLoader;

+ (DYImageLoader*)imageLoader;

+ (DYImageLoader*)imageLoaderWithCacheCapacity:(NSUInteger)capacity;

- (instancetype)initWithCacheCapacity:(NSUInteger)capacity;

- (void)loadImageForUIImageView:(UIImageView*)uiImageView url:(NSString*)url failure:(void(^)(void))failure success:(void(^)(void))success;

@end

NS_ASSUME_NONNULL_END
