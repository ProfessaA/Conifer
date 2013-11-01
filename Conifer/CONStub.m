#import "CONStub.h"
#import <objc/runtime.h>

@interface CONStub ()

@property (nonatomic, weak) Class originalClass;
@property (nonatomic, weak) Class stubClass;
@property (nonatomic, assign) SEL stubSEL;
@property (nonatomic, assign) SEL originalSEL;

@end

@implementation CONStub

- (id)initWithObject:(id)object originalSelector:(SEL)originalSEL stubSelector:(SEL)stubSEL
{
    if (self = [super init]) {
        self.stubClass = object_getClass(object);
        self.originalClass = class_getSuperclass(self.stubClass);
        self.originalSEL = originalSEL;
        self.stubSEL = stubSEL;
    }
    return self;
}

- (void)andCallThrough
{
    Method unstubbedMethod = class_getInstanceMethod(self.originalClass, self.originalSEL);
    [self stubWithIMP:method_getImplementation(unstubbedMethod)];
}

- (void)andReturn:(void *)returnValue
{
    [self stubWithIMP:imp_implementationWithBlock(^{ return returnValue; })];
}

- (void)andCallFake:(id)block
{
    [self stubWithIMP:imp_implementationWithBlock(block)];
}

# pragma mark - Private

- (void)stubWithIMP:(IMP)stubIMP
{
    Method unstubbedMethod = class_getInstanceMethod(self.originalClass, self.originalSEL);
    
    class_replaceMethod(self.stubClass,
                        self.stubSEL,
                        stubIMP,
                        method_getTypeEncoding(unstubbedMethod));
}

@end
