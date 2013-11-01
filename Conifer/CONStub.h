#import <UIKit/UIKit.h>

@interface CONStub : UICollectionViewController

- (id)initWithObject:(id)object originalSelector:(SEL)originalSEL stubSelector:(SEL)stubSEL;

- (void)andCallThrough;

- (void)andReturn:(void *)returnValue;

- (void)andCallFake:(id)block;

@end
