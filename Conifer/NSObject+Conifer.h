#import <Foundation/Foundation.h>
#import "CONStub.h"

extern NSString * const ConiferStubException;

@interface NSObject (Conifer)

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
