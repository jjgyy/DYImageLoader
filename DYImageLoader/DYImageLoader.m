//
//  DYImageLoader.m
//  DYImageLoader
//
//  Created by Apple on 2019/3/15.
//  Copyright © 2019 Young. All rights reserved.
//

#import "DYImageLoader.h"

@implementation DYImageLoader {
    NSCache* _cacheOfImageData;
    NSUInteger _numberOfConcurrentQueues;
    NSArray* _arrayOfSerialQueuesPool;
    dispatch_semaphore_t _semaphoreAvoidingRepeatingRequests;
}

static DYImageLoader* _sharedImageLoader;
static int _requestCount = 0;

+ (DYImageLoader*)sharedImageLoader {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedImageLoader = [[DYImageLoader alloc] init];
    });
    return _sharedImageLoader;
}

+ (DYImageLoader*)imageLoader {
    return [[DYImageLoader alloc] init];
}

+ (DYImageLoader*)imageLoaderWithCacheLimit:(NSUInteger)limit concurrentRequestsNumber:(NSUInteger)number {
    return [[DYImageLoader alloc] initWithCacheLimit:limit concurrentRequestsNumber:number];
}

- (instancetype)init {
    return [self initWithCacheLimit:DY_DEFAULT_LIMIT_OF_IMAGE_CACHE concurrentRequestsNumber:DY_DEFAULT_NUMBER_OF_CONCURRENT_REQUESTS];
}

- (instancetype)initWithCacheLimit:(NSUInteger)limit concurrentRequestsNumber:(NSUInteger)number {
    if (self = [super init]) {
        self->_cacheOfImageData = [[NSCache alloc] init];
        self->_cacheOfImageData.countLimit = 100;
        self->_cacheOfImageData.totalCostLimit = limit;
        self->_semaphoreAvoidingRepeatingRequests = dispatch_semaphore_create(1);
        self->_numberOfConcurrentQueues = number;
        NSMutableArray* arrayOfSerialQueues = [NSMutableArray new];
        for (int i=0; i<number; i++) {
            [arrayOfSerialQueues addObject:dispatch_queue_create("com.DYImageLoader", DISPATCH_QUEUE_SERIAL)];
        }
        self->_arrayOfSerialQueuesPool = arrayOfSerialQueues;
    }
    return self;
}

- (void)loadImageWithURL:(NSString *)url completion:(DYUIImageLoadingCompletionHandler)completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //try to get image cache from dict
        NSData* imageData = (NSData*)[self->_cacheOfImageData objectForKey:url];
        UIImage* image = [UIImage imageWithData:imageData];
        if (image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(image);
            });
            return;
        }
        else {
            //begin to request from a new url
            dispatch_semaphore_wait(self->_semaphoreAvoidingRepeatingRequests, DISPATCH_TIME_FOREVER);
            if (![self->_cacheOfImageData objectForKey:url]) {
                //thread which is the first one try to request a new url, begin requesting
                [self->_cacheOfImageData setObject:@"" forKey:url];
                dispatch_async(self->_arrayOfSerialQueuesPool[[url hash] % self->_numberOfConcurrentQueues], ^{
                    NSData* imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
                    _requestCount ++;
                    UIImage* uiImageInResponse = [UIImage imageWithData:imageData];
                    if (!uiImageInResponse) {return;}
                    [self->_cacheOfImageData setObject:imageData forKey:url cost:imageData.length];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(uiImageInResponse);
                    });
                });
                //signal the semaphore, then return
                dispatch_semaphore_signal(self->_semaphoreAvoidingRepeatingRequests);
                return;
            }
            //thread which isn't the first one try to request a new url, signal the semaphore without doing anything
            dispatch_semaphore_signal(self->_semaphoreAvoidingRepeatingRequests);
            //join the serial queue, wait to get image data from cache
            dispatch_async(self->_arrayOfSerialQueuesPool[[url hash] % self->_numberOfConcurrentQueues], ^{
                NSData* imageData = [self->_cacheOfImageData objectForKey:url];
                UIImage* image = [UIImage imageWithData:imageData];
                if (image) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(image);
                    });
                }
            });
            
        }
    });
}

- (void)loadImageForUIImageView:(UIImageView *)uiImageView withURL:(NSString *)url completion:(DYUIImageViewSettingCompletionHandler)completion {
    __weak UIImageView* weakUIImageView = uiImageView;
    [self loadImageWithURL:url completion:^(UIImage * _Nullable image) {
        __strong UIImageView* strongUIImageView = weakUIImageView;
        strongUIImageView.image = image;
        completion();
    }];
}

- (void)loadImageForUIImageViews:(NSArray *)uiImageViews withURL:(NSString *)url {
    [self loadImageWithURL:url completion:^(UIImage * _Nullable image) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [uiImageViews enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    ((UIImageView*)obj).image = image;
                });
            }];
        });
    }];
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: %p, %@}>",
            [self class],
            self,
            @{
              @"cacheLimit":[NSNumber numberWithUnsignedInteger:_cacheOfImageData.totalCostLimit],
              @"requestCount":[NSNumber numberWithInt:_requestCount]
              }];
}

- (NSString *)debugDescription {
    return [self description];
}

@end
