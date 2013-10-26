#import "NSObject+EverGreen.h"
#import <objc/runtime.h>

const char *stubbedMethodsKey = "stubbedMethods";
const char *stubClassKey = "stubClass";

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

- (void)unstub
{
    if (![self isStubbed]) return;
    
    objc_setAssociatedObject(self, stubClassKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, stubbedMethodsKey, nil, OBJC_ASSOCIATION_ASSIGN);
    object_setClass(self, [self class]);
}

- (void)stub:(SEL)selector
{
    if ([self isSelectorStubbed:selector]) return;
    
    if (![self isStubbed]) [self stub];
    
    objc_setAssociatedObject(self,
                             stubbedMethodsKey,
                             [@[NSStringFromSelector(selector)] arrayByAddingObjectsFromArray:[self stubbedMethods]],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    Method originalMethod = class_getInstanceMethod([self class], selector);
    const char *methodTypes = method_getTypeEncoding(originalMethod);
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    IMP defaultStub = imp_implementationWithBlock(^(id me, ...) { return nil; });
    class_addMethod([self stubClass], stubbedSEL, defaultStub, methodTypes);
    
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:methodTypes];
    IMP stubImp = imp_implementationWithBlock(^void* (id me, ...) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setSelector:stubbedSEL];
        
        va_list args;
        va_start(args, me);
        NSUInteger numArguments = [signature numberOfArguments];
        for (int i = 2; i < numArguments; i++) {
            void *arg = va_arg(args, void *);
            [invocation setArgument:&arg atIndex:i];
        }
        va_end(args);
        
        [invocation invokeWithTarget:me];
        NSString *retType = [NSString stringWithUTF8String:[signature methodReturnType]];
        if ([retType isEqualToString:@"v"]) return nil;
        
        void *retVal;
        [invocation getReturnValue:&retVal];
        return retVal;
    });
    
    class_addMethod([self stubClass], selector, stubImp, methodTypes);
}

- (void)stubAndCallThrough:(SEL)selector
{
    [self stub:selector];
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    Method unstubbedMethod = class_getInstanceMethod([self class], selector);
    
    class_replaceMethod([self stubClass],
                        stubbedSEL,
                        method_getImplementation(unstubbedMethod),
                        method_getTypeEncoding(unstubbedMethod));
}

- (void)stub:(SEL)selector andReturn:(void *)returnValue
{
    [self stub:selector];
    
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    IMP stubbedIMP = imp_implementationWithBlock(^{ return returnValue; });
    Method unstubbedMethod = class_getInstanceMethod([self class], selector);
    
    class_replaceMethod([self stubClass],
                        stubbedSEL,
                        stubbedIMP,
                        method_getTypeEncoding(unstubbedMethod));
}

- (void)stub:(SEL)selector andCallFake:(id)block
{
    [self stub:selector];
    
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    IMP stubbedIMP = imp_implementationWithBlock(block);
    SEL unstubbedSEL = unstubbedSelectorForSelector(selector);
    
    class_replaceMethod([self stubClass],
                        stubbedSEL,
                        stubbedIMP,
                        method_getTypeEncoding(class_getInstanceMethod([self class], unstubbedSEL)));
}

# pragma mark - Private

- (void)stub
{
    Class originalClass = [self class];
    IMP classIMP = imp_implementationWithBlock(^{ return originalClass; });
    
    NSString *objectMetaClassName = [NSString stringWithFormat:@"%@%p", NSStringFromClass([self class]), self];
    Class objectMetaClass = objc_allocateClassPair([self class], [objectMetaClassName UTF8String], 0);
    if (objectMetaClass) {
        objc_registerClassPair(objectMetaClass);
        object_setClass(self, objectMetaClass);
    }
    
    class_addMethod([self class], @selector(class), classIMP, "@@:");
    objc_setAssociatedObject(self, stubClassKey, objectMetaClass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (Class)stubClass
{
    return objc_getAssociatedObject(self, stubClassKey);
}

- (BOOL)isStubbed
{
    return objc_getAssociatedObject(self, stubClassKey) != nil;
}

- (NSArray *)stubbedMethods
{
    return objc_getAssociatedObject(self, stubbedMethodsKey);
}

- (BOOL)isSelectorStubbed:(SEL)selector
{
    return [[self stubbedMethods] containsObject:NSStringFromSelector(selector)];
}

@end
