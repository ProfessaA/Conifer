#import <Foundation/Foundation.h>

@interface NSObject (EverGreen)

- (void)stub:(SEL)selector;

- (void)stubAndCallThrough:(SEL)selector;

- (void)stub:(SEL)selector andReturn:(void *)returnValue;

- (void)stub:(SEL)selector andCallFake:(id)block;

@end
