# DYImageLoader

---
A smart, quick iOS image loader
by David Young

---

## Advantages
- Image cache
- Multithread optimization, avoid repeated loading

## Quick Start
1. import the .h file
```
#import "DYImageLoader.h"
```

2. use happily
```
[DYImageLoader.sharedImageLoader loadImageForUIImageView:self.uiImageView url:url failure:^{} success:^{}];
```

