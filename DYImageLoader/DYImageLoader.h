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
@property(class, nonatomic, readonly, strong) DYImageLoader* sharedImageLoader;

+ (DYImageLoader*)imageLoader;

+ (DYImageLoader*)imageLoaderWithCacheCapacity:(NSUInteger)capacity concurrentRequestsNumber:(NSUInteger)number;

- (instancetype)initWithCacheCapacity:(NSUInteger)capacity concurrentRequestsNumber:(NSUInteger)number;

- (void)loadImageWithURL:(NSString*)url completion:(void (^)(UIImage* _Nullable image))completion;

- (void)loadImageForUIImageView:(UIImageView*)uiImageView withURL:(NSString*)url completion:(void (^)(void))completion;

- (void)loadImageForUIImageViews:(NSArray*)uiImageViews withURL:(NSString*)url;

@end

NS_ASSUME_NONNULL_END
