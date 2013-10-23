#import "NSObject+EverGreen.h"
#import <objc/runtime.h>

const char *isStubbed = "isStubbed";
const char *stubbedMethods = "stubbedMethods";

SEL unstubbedSelectorForSelector(SEL selector)
{
    NSString *selectorString = NSStringFromSelector(selector);
    selectorString = [selectorString stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                                             withString:[[selectorString substringToIndex:1] uppercaseString]];
    return NSSelectorFromString([@"_unstubbed" stringByAppendingString:selectorString]);
}

SEL stubbedSelectorForSelector(SEL selector)
{
    NSString *selectorString = NSStringFromSelector(selector);
    selectorString = [selectorString stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                                             withString:[[selectorString substringToIndex:1] uppercaseString]];
    return NSSelectorFromString([@"_stubbed" stringByAppendingString:selectorString]);
}

@implementation NSObject (EverGreen)

- (void)stub:(SEL)selector
{
    if ([objc_getAssociatedObject(self, isStubbed) boolValue] == YES) return;
    objc_setAssociatedObject(self, isStubbed, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    Class class = [self class];
    Method unstubbedMethod = class_getInstanceMethod(class, selector);
    IMP unstubbedMethodImp = method_getImplementation(unstubbedMethod);
    SEL unstubbedSEL = unstubbedSelectorForSelector(selector);

    const char *unstubbedTypes = method_getTypeEncoding(unstubbedMethod);
    class_addMethod(class, unstubbedSEL, unstubbedMethodImp, unstubbedTypes);
    
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    IMP defaultStub = imp_implementationWithBlock(^(id me, ...) { return nil; });
    class_addMethod(class, stubbedSEL, defaultStub, unstubbedTypes);
    
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(unstubbedMethod)];
    IMP stubImp = imp_implementationWithBlock(^void* (id me, ...) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:me];
        
        va_list args;
        va_start(args, me);
        NSUInteger numArguments = [signature numberOfArguments];
        for (int i = 2; i < numArguments; i++) {
            void *arg = va_arg(args, void *);
            [invocation setArgument:&arg atIndex:i];
        }
        va_end(args);
        
        if ([objc_getAssociatedObject(me, isStubbed) boolValue] == NO) {
            [invocation setSelector:unstubbedSEL];
        } else {
            [invocation setSelector:stubbedSEL];
        }
        
        [invocation invoke];
        NSString *retType = [NSString stringWithUTF8String:[signature methodReturnType]];
        if ([retType isEqualToString:@"v"]) return nil;
        
        void *retVal;
        [invocation getReturnValue:&retVal];
        return retVal;
    });
    
    method_setImplementation(unstubbedMethod, stubImp);
}

- (void)stubAndCallThrough:(SEL)selector
{
    [self stub:selector];
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    SEL unstubbedSEL = unstubbedSelectorForSelector(selector);
    Method unstubbedMethod = class_getInstanceMethod([self class], unstubbedSEL);
    
    class_replaceMethod([self class],
                        stubbedSEL,
                        method_getImplementation(unstubbedMethod),
                        method_getTypeEncoding(unstubbedMethod));
}

- (void)stub:(SEL)selector andReturn:(void *)returnValue
{
    [self stub:selector];
    
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    IMP stubbedIMP = imp_implementationWithBlock(^{ return returnValue; });
    SEL unstubbedSEL = unstubbedSelectorForSelector(selector);
    
    class_replaceMethod([self class],
                        stubbedSEL,
                        stubbedIMP,
                        method_getTypeEncoding(class_getInstanceMethod([self class], unstubbedSEL)));
}

- (void)stub:(SEL)selector andCallFake:(id)block
{
    [self stub:selector];
    
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    IMP stubbedIMP = imp_implementationWithBlock(block);
    SEL unstubbedSEL = unstubbedSelectorForSelector(selector);
    
    class_replaceMethod([self class],
                        stubbedSEL,
                        stubbedIMP,
                        method_getTypeEncoding(class_getInstanceMethod([self class], unstubbedSEL)));
}

@end
