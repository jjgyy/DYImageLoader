//
//  DYImageLoader.m
//  DYImageLoader
//
//  Created by Apple on 2019/3/15.
//  Copyright © 2019 Young. All rights reserved.
//
#define DY_DEFAULT_CAPACITY_OF_IMAGE_CACHE 20
#define DY_DEFAULT_CAPACITY_OF_REQUESTING_URLS 100

#import "DYImageLoader.h"

@interface DYImageLoader()
@property(nonatomic, assign) NSUInteger capacityOfImageCache;
@property(nonatomic, strong) NSMutableDictionary* dictOfImages;
@property(nonatomic, strong) NSMutableArray* arrayOfSequencedURLs;
@property(nonatomic, strong) NSMutableDictionary* dictOfRequestingQueues;
@property(nonatomic, strong) NSLock* lockOfCheckImageCacheOverflow;
@property(nonatomic, strong) dispatch_semaphore_t semaphoreOfDictOfRequestingQueues;
@end

@implementation DYImageLoader

static DYImageLoader* _sharedImageLoader;

+ (DYImageLoader*)sharedImageLoader {
    if (!_sharedImageLoader) {
        _sharedImageLoader = [DYImageLoader new];
    }
    return _sharedImageLoader;
}

+ (DYImageLoader*)imageLoader {
    return [[DYImageLoader alloc] init];
}

+ (DYImageLoader*)imageLoaderWithCacheCapacity:(NSUInteger)capacity {
    return [[DYImageLoader alloc] initWithCacheCapacity:capacity];
}

- (instancetype)init {
    if (self = [super init]) {
        self.capacityOfImageCache = DY_DEFAULT_CAPACITY_OF_IMAGE_CACHE;
        self.dictOfImages = [NSMutableDictionary dictionaryWithCapacity:DY_DEFAULT_CAPACITY_OF_IMAGE_CACHE + 10];
        self.arrayOfSequencedURLs = [NSMutableArray arrayWithCapacity:DY_DEFAULT_CAPACITY_OF_IMAGE_CACHE + 10];
        self.dictOfRequestingQueues = [NSMutableDictionary dictionaryWithCapacity:DY_DEFAULT_CAPACITY_OF_REQUESTING_URLS];
        self.lockOfCheckImageCacheOverflow = [NSLock new];
        self.semaphoreOfDictOfRequestingQueues = dispatch_semaphore_create(1);
    }
    return self;
}

- (instancetype)initWithCacheCapacity:(NSUInteger)capacity {
    if (self = [super init]) {
        self.capacityOfImageCache = capacity;
        self.dictOfImages = [NSMutableDictionary dictionaryWithCapacity:capacity + 10];
        self.arrayOfSequencedURLs = [NSMutableArray arrayWithCapacity:capacity + 10];
        self.dictOfRequestingQueues = [NSMutableDictionary dictionaryWithCapacity:DY_DEFAULT_CAPACITY_OF_REQUESTING_URLS];
        self.lockOfCheckImageCacheOverflow = [NSLock new];
        self.semaphoreOfDictOfRequestingQueues = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)loadImageForUIImageView:(UIImageView*)uiImageView url:(NSString*)url failure:(void(^)(void))failure success:(void(^)(void))success {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //try to get image cache from dict
        UIImage* uiImageInDict = (UIImage*)[self.dictOfImages objectForKey:url];
        if (uiImageInDict) {
            dispatch_async(dispatch_get_main_queue(), ^{
                uiImageView.image = uiImageInDict;
            });
        }
        else {
            //begin to request from url
            //try to get requesting queue from dict
            dispatch_queue_t queue = (dispatch_queue_t)[self.dictOfRequestingQueues objectForKey:url];
            if (!queue) {
                //begin to create new request queue
                //guarantee that at one time there is only one thread updating the requesting-queue-dict
                dispatch_semaphore_wait(self.semaphoreOfDictOfRequestingQueues, DISPATCH_TIME_FOREVER);
                //thread invoked by semaphore check dict again
                queue = (dispatch_queue_t)[self.dictOfRequestingQueues objectForKey:url];
                if (!queue) {
                    //create a new queue, then create the first block in the queue
                    queue = dispatch_queue_create("david", DISPATCH_QUEUE_SERIAL);
                    [self.dictOfRequestingQueues setObject:queue forKey:url];
                    dispatch_async(queue, ^{
                        NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
                        UIImage* uiImageInResponse = [UIImage imageWithData:data];
                        if (!uiImageInResponse) {failure();}
                        dispatch_async(dispatch_get_main_queue(), ^{
                            uiImageView.image = uiImageInResponse;
                        });
                        [self.dictOfImages setObject:uiImageInResponse forKey:url];
                        [self.arrayOfSequencedURLs addObject:url];
                        [self checkImageCacheOverflow];
                        success();
                    });
                    //signal the semaphore, then return
                    dispatch_semaphore_signal(self.semaphoreOfDictOfRequestingQueues);
                    return;
                }
                //thread which doesn't get the semaphore first, signal the semaphore without doing anything
                dispatch_semaphore_signal(self.semaphoreOfDictOfRequestingQueues);
            }
            dispatch_async(queue, ^{
                UIImage* uiImageInDict = (UIImage*)[self.dictOfImages objectForKey:url];
                if (uiImageInDict) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        uiImageView.image = uiImageInDict;
                    });
                    success();
                }
                else {
                    failure();
                }
            });
            
        }
    });
}

- (void)checkImageCacheOverflow {
    if ([self.lockOfCheckImageCacheOverflow tryLock]) {
        while (self.arrayOfSequencedURLs.count > self.capacityOfImageCache) {
            [self.dictOfImages removeObjectForKey:(NSString*)[self.arrayOfSequencedURLs objectAtIndex:0]];
            [self.dictOfRequestingQueues removeObjectForKey:(NSString*)[self.arrayOfSequencedURLs objectAtIndex:0]];
            [self.arrayOfSequencedURLs removeObjectAtIndex:0];
        }
        [self.lockOfCheckImageCacheOverflow unlock];
    }
}

@end
