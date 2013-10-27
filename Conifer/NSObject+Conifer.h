#import <Foundation/Foundation.h>

extern NSString * const ConiferStubException;

@interface NSObject (Conifer)

- (BOOL)isStubbingMethod:(SEL)selector;

- (BOOL)isStubbingMethods;

- (void)unstub;

- (void)stub:(SEL)selector;

- (void)stubAndCallThrough:(SEL)selector;

- (void)stub:(SEL)selector andReturn:(void *)returnValue;

- (void)stub:(SEL)selector andCallFake:(id)block;

@end

@interface NSObject (ConiferClassMethods)

+ (BOOL)isStubbingMethod:(SEL)selector;

+ (BOOL)isStubbingMethods;

+ (void)unstub;

+ (void)stub:(SEL)selector;

+ (void)stubAndCallThrough:(SEL)selector;

+ (void)stub:(SEL)selector andReturn:(void *)returnValue;

+ (void)stub:(SEL)selector andCallFake:(id)block;

@end
