#import <Foundation/Foundation.h>

extern NSString * const ConiferStubException;

@interface NSObject (Conifer)

#pragma mark - Any Instance Stubs

+ (void)anyInstanceUnstub;

+ (void)anyInstanceUnstub:(SEL)selector;

+ (void)anyInstanceStub:(SEL)selector;

+ (BOOL)isStubbingAnyInstanceMethods;

+ (BOOL)isStubbingAnyInstanceMethod:(SEL)selector;

#pragma mark - Instance Stubs

- (BOOL)isStubbingMethod:(SEL)selector;

- (BOOL)isStubbingMethods;

- (void)unstub;

- (void)stub:(SEL)selector;

- (void)stubAndCallThrough:(SEL)selector;

- (void)stub:(SEL)selector andReturn:(void *)returnValue;

- (void)stub:(SEL)selector andCallFake:(id)block;

@end

@interface NSObject (ConiferClassStubbing)

+ (BOOL)isStubbingMethod:(SEL)selector;

+ (BOOL)isStubbingMethods;

+ (void)unstub;

+ (void)stub:(SEL)selector;

+ (void)stubAndCallThrough:(SEL)selector;

+ (void)stub:(SEL)selector andReturn:(void *)returnValue;

+ (void)stub:(SEL)selector andCallFake:(id)block;

@end
