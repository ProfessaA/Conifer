#import <Foundation/Foundation.h>
#import "CONStub.h"

extern NSString * const ConiferStubException;

@interface NSObject (Conifer)

- (BOOL)isStubbingMethod:(SEL)selector;

- (BOOL)isStubbingMethods;

- (void)unstub;

- (CONStub *)stub:(SEL)selector;

- (CONStub *)stub:(SEL)selector with:(void *)firstArgument, ...;

- (BOOL)didReceive:(SEL)selector;

- (BOOL)didReceive:(SEL)selector with:(void *)firstArgument, ...;

@end

@interface NSObject (ConiferClassStubbing)

+ (BOOL)isStubbingMethod:(SEL)selector;

+ (BOOL)isStubbingMethods;

+ (void)unstub;

+ (CONStub *)stub:(SEL)selector;

- (CONStub *)stub:(SEL)selector with:(void *)firstArgument, ...;

- (BOOL)didReceive:(SEL)selector;

- (BOOL)didReceive:(SEL)selector with:(void *)firstArgument, ...;

@end