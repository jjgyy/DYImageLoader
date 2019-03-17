# DYImageLoader

---
A smart, quick iOS image loader
by David Young

---

## Advantages
- Image Cache    图片缓存
- Multithread optimization, avoid repeated loading    多线程优化，避免重复加载

## Quick Start
1. import the .h file    导入.h文件
```
#import "DYImageLoader.h"
```

2. use DYImageLoader    使用DYImageLoader
```
DYImageLoader * imageLoader = DYImageLoader.sharedImageLoader;
```


## API
1. loadImageWithURL
```
- (void)loadImageWithURL:(NSString*)url completion:(void (^)(UIImage* _Nullable image))completion;
```
>异步加载图片，优先从图片缓存中读取，如果没有则发起请求。多个线程同时发起针对同一URL的请求将只保留一个

---

2. loadImageForUIImageView
```
- (void)loadImageForUIImageView:(UIImageView*)uiImageView withURL:(NSString*)url completion:(void (^)(void))completion;
```
>调用loadImageWithURL，之后为UIImageView设置image

---

3. loadImageForUIImageViews
```
- (void)loadImageForUIImageViews:(NSArray*)uiImageViews withURL:(NSString*)url completion:(void (^)(void))completion;
```
>调用loadImageWithURL，之后使用dispatch_apply进行并发迭代，为数组中所有UIImageView设置image

---


## Structure
![avatar](http://assets.processon.com/chart_image/5c8dbde7e4b0afc744146e15.png)

