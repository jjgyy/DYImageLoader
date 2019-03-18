//
//  DYImageLoader.m
//  DYImageLoader
//
//  Created by Apple on 2019/3/15.
//  Copyright © 2019 Young. All rights reserved.
//
#define DY_DEFAULT_CAPACITY_OF_IMAGE_CACHE 20
#define DY_DEFAULT_NUMBER_OF_CONCURRENT_REQUESTS 3

#import "DYImageLoader.h"

@interface DYImageLoader()
@property(nonatomic, assign) NSUInteger capacityOfImageCache;
@property(nonatomic, assign) NSUInteger numberOfConcurrentQueues;
@property(nonatomic, strong) NSMutableDictionary* dictOfImages;
@property(nonatomic, strong) NSMutableArray* arrayOfSequencedURLs;
@property(nonatomic, strong) NSMutableDictionary* dictOfQueueIndexToJoin;
@property(nonatomic, strong) NSArray* arrayOfSerialQueuesPool;
@property(nonatomic, strong) NSLock* lockOfCheckImageCacheOverflow;
@property(nonatomic, strong) dispatch_semaphore_t semaphoreOfSequencedURLsArray;
@end

@implementation DYImageLoader

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

+ (DYImageLoader*)imageLoaderWithCacheCapacity:(NSUInteger)capacity concurrentRequestsNumber:(NSUInteger)number {
    return [[DYImageLoader alloc] initWithCacheCapacity:capacity concurrentRequestsNumber:number];
}

- (instancetype)init {
    return [self initWithCacheCapacity:DY_DEFAULT_CAPACITY_OF_IMAGE_CACHE concurrentRequestsNumber:DY_DEFAULT_NUMBER_OF_CONCURRENT_REQUESTS];
}

- (instancetype)initWithCacheCapacity:(NSUInteger)capacity concurrentRequestsNumber:(NSUInteger)number {
    if (self = [super init]) {
        self->_capacityOfImageCache = 10;
        self->_dictOfImages = [NSMutableDictionary dictionaryWithCapacity:capacity + 10];
        self->_arrayOfSequencedURLs = [NSMutableArray arrayWithCapacity:capacity + 10];
        self->_dictOfQueueIndexToJoin = [NSMutableDictionary dictionaryWithCapacity:capacity + 10];
        self->_lockOfCheckImageCacheOverflow = [[NSLock alloc] init];
        self->_semaphoreOfSequencedURLsArray = dispatch_semaphore_create(1);
        self->_numberOfConcurrentQueues = number;
        NSMutableArray* arrayOfSerialQueues = [NSMutableArray new];
        for (int i=0; i<number; i++) {
            [arrayOfSerialQueues addObject:dispatch_queue_create("com.DYImageLoader", DISPATCH_QUEUE_SERIAL)];
        }
        self->_arrayOfSerialQueuesPool = arrayOfSerialQueues;
    }
    return self;
}

- (void)loadImageWithURL:(NSString *)url completion:(void (^)(UIImage * _Nullable))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //try to get image cache from dict
        UIImage* uiImageInDict = (UIImage*)self->_dictOfImages[url];
        if (uiImageInDict) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(uiImageInDict);
            });
            return;
        }
        else {
            //begin to request from a new url
            dispatch_semaphore_wait(self->_semaphoreOfSequencedURLsArray, DISPATCH_TIME_FOREVER);
            if (![self->_arrayOfSequencedURLs containsObject:url]) {
                NSUInteger indexOfURLInArray = self->_arrayOfSequencedURLs.count;
                NSUInteger indexOfQueueToJoin = indexOfURLInArray % self->_numberOfConcurrentQueues;
                [self->_arrayOfSequencedURLs addObject:url];
                [self->_dictOfQueueIndexToJoin setObject:[NSNumber numberWithUnsignedInteger:indexOfQueueToJoin] forKey:url];
                //thread which is the first one try to request a new url, begin requesting
                dispatch_async(self->_arrayOfSerialQueuesPool[indexOfQueueToJoin], ^{
                    NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
                    _requestCount ++;
                    UIImage* uiImageInResponse = [UIImage imageWithData:data];
                    if (!uiImageInResponse) {return;}
                    self->_dictOfImages[url] = uiImageInResponse;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(uiImageInResponse);
                    });
                    [self p_avoidImageCacheOverflow];
                });
                //signal the semaphore, then return
                dispatch_semaphore_signal(self->_semaphoreOfSequencedURLsArray);
                return;
            }
            //thread which isn't the first one try to request a new url, signal the semaphore without doing anything
            dispatch_semaphore_signal(self->_semaphoreOfSequencedURLsArray);
            //join the serial queue, wait to get image data from dict
            NSUInteger indexOfQueueToJoin = [(NSNumber*)self->_dictOfQueueIndexToJoin[url] integerValue];
            dispatch_async(self->_arrayOfSerialQueuesPool[indexOfQueueToJoin], ^{
                UIImage* uiImageInDict = (UIImage*)self->_dictOfImages[url];
                if (uiImageInDict) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(uiImageInDict);
                    });
                }
            });
            
        }
    });
}

- (void)loadImageForUIImageView:(UIImageView *)uiImageView withURL:(NSString *)url completion:(void (^)(void))completion {
    __weak UIImageView* weakUIImageView = uiImageView;
    [self loadImageWithURL:url completion:^(UIImage * _Nullable image) {
        __strong UIImageView* strongUIImageView = weakUIImageView;
        strongUIImageView.image = image;
        completion();
    }];
}

- (void)loadImageForUIImageViews:(NSArray *)uiImageViews withURL:(NSString *)url {
    __weak NSArray* weakUIImageViews = uiImageViews;
    [self loadImageWithURL:url completion:^(UIImage * _Nullable image) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __strong NSArray* strongUIImageViews = weakUIImageViews;
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            //dispatch_apply run very fast :)
            dispatch_apply(uiImageViews.count, queue, ^(size_t index) {
                UIImageView* uiImageView = (UIImageView*)strongUIImageViews[index];
                dispatch_async(dispatch_get_main_queue(), ^{
                    uiImageView.image = image;
                });
            });
        });
    }];
}

- (void)p_avoidImageCacheOverflow {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([self->_lockOfCheckImageCacheOverflow tryLock]) {
            while (self->_arrayOfSequencedURLs.count > self->_capacityOfImageCache) {
                NSString* removedURL = (NSString*)self->_arrayOfSequencedURLs[0];
                if (self->_dictOfImages[removedURL] && self->_dictOfQueueIndexToJoin[removedURL]) {
                    [self->_dictOfImages removeObjectForKey:removedURL];
                    [self->_dictOfQueueIndexToJoin removeObjectForKey:removedURL];
                    [self->_arrayOfSequencedURLs removeObjectAtIndex:0];
                }
            }
            [self->_lockOfCheckImageCacheOverflow unlock];
        }
    });
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: %p, %@}>",
            [self class],
            self,
            @{
              @"requestCount":[NSNumber numberWithInt:_requestCount],
              @"arrayOfSequencedURLs":_arrayOfSequencedURLs,
              @"dictOfQueueIndexToJoin":_dictOfQueueIndexToJoin,
              @"dictOfImages":_dictOfImages
              }];
}

- (NSString *)debugDescription {
    return [self description];
}

@end
