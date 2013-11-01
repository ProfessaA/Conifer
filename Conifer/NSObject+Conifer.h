#import <Foundation/Foundation.h>
#import "CONStub.h"

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

- (CONStub *)stub:(SEL)selector;

@end

@interface NSObject (ConiferClassStubbing)

+ (BOOL)isStubbingMethod:(SEL)selector;

+ (BOOL)isStubbingMethods;

+ (void)unstub;

+ (CONStub *)stub:(SEL)selector;

@end
