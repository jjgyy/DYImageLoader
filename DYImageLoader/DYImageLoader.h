//
//  DYImageLoader.h
//  DYImageLoader
//
//  Created by Apple on 2019/3/15.
//  Copyright © 2019 Young. All rights reserved.
//
#define DY_DEFAULT_CAPACITY_OF_IMAGE_CACHE 20
#define DY_DEFAULT_NUMBER_OF_CONCURRENT_REQUESTS 3

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^DYUIImageLoadingCompletionHandler)(UIImage* _Nullable image);
typedef void (^DYUIImageViewSettingCompletionHandler)(void);

@interface DYImageLoader : NSObject
@property(class, nonatomic, readonly, strong) DYImageLoader* sharedImageLoader;

+ (DYImageLoader*)imageLoader;

+ (DYImageLoader*)imageLoaderWithCacheCapacity:(NSUInteger)capacity concurrentRequestsNumber:(NSUInteger)number;

- (instancetype)initWithCacheCapacity:(NSUInteger)capacity concurrentRequestsNumber:(NSUInteger)number;

- (void)loadImageWithURL:(NSString*)url completion:(DYUIImageLoadingCompletionHandler)completion;

- (void)loadImageForUIImageView:(UIImageView*)uiImageView withURL:(NSString*)url completion:(DYUIImageViewSettingCompletionHandler)completion;

- (void)loadImageForUIImageViews:(NSArray*)uiImageViews withURL:(NSString*)url;

@end

NS_ASSUME_NONNULL_END
