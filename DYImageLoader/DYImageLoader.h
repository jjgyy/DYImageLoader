//
//  DYImageLoader.h
//  DYImageLoader
//
//  Created by Apple on 2019/3/15.
//  Copyright © 2019 Young. All rights reserved.
//
#define DY_DEFAULT_LIMIT_OF_IMAGE_CACHE (20 * 1024 * 1024)
#define DY_DEFAULT_NUMBER_OF_CONCURRENT_REQUESTS 5

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^DYUIImageLoadingCompletionHandler)(UIImage* _Nullable image);
typedef void (^DYUIImageViewSettingCompletionHandler)(void);

@interface DYImageLoader : NSObject
@property(class, nonatomic, readonly, strong) DYImageLoader* sharedImageLoader;

+ (DYImageLoader*)imageLoader;

+ (DYImageLoader*)imageLoaderWithCacheLimit:(NSUInteger)limit concurrentRequestsNumber:(NSUInteger)number;

- (instancetype)initWithCacheLimit:(NSUInteger)limit concurrentRequestsNumber:(NSUInteger)number;

- (void)loadImageWithURL:(NSString*)url completion:(DYUIImageLoadingCompletionHandler)completion;

- (void)loadImageForUIImageView:(UIImageView*)uiImageView withURL:(NSString*)url completion:(DYUIImageViewSettingCompletionHandler)completion;

- (void)loadImageForUIImageViews:(NSArray*)uiImageViews withURL:(NSString*)url;

@end

NS_ASSUME_NONNULL_END
