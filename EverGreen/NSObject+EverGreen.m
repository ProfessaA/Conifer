#import "NSObject+EverGreen.h"
#import <objc/runtime.h>
#import <objc/message.h>

NSString * const EverGreenStubException = @"EverGreenStubException";

const char *stubbedMethodsKey = "stubbedMethodsKey";
const char *isStubbedKey = "isStubbedKey";

#pragma mark - Utility Functions

SEL stubbedSelectorForSelector(SEL selector)
{
    NSString *selectorString = NSStringFromSelector(selector);
    selectorString = [selectorString stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                                             withString:[[selectorString substringToIndex:1] uppercaseString]];
    return NSSelectorFromString([@"_stubbed" stringByAppendingString:selectorString]);
}

#pragma mark - Stubbing Meta Information

BOOL isStubbed(id self)
{
    return [objc_getAssociatedObject(self, isStubbedKey) boolValue];
}

NSArray * stubbedMethodsForObject(id self)
{
    return objc_getAssociatedObject(self, stubbedMethodsKey);
}

BOOL isSelectorStubbedForObject(SEL selector, id self)
{
    return [stubbedMethodsForObject(self) containsObject:NSStringFromSelector(selector)];
}

void addSelectorToStubbedMethodListForObject(SEL selector, id self)
{
    NSString *selectorString = NSStringFromSelector(selector);
    
    objc_setAssociatedObject(self,
                             stubbedMethodsKey,
                             [@[selectorString] arrayByAddingObjectsFromArray:stubbedMethodsForObject(self)],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Creating Initial Stub Method

id stubBlockForSelectorWithMethodSignature(SEL selector, NSMethodSignature *signature)
{
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    return ^void* (id me, ...) {
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
    };
}

void addStubMethodForSelector(id self, SEL selector)
{
    Method originalMethod = class_getInstanceMethod(class_getSuperclass(object_getClass(self)), selector);
    const char *methodTypes = method_getTypeEncoding(originalMethod);
    
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    IMP defaultStub = imp_implementationWithBlock(^(id me, ...) { return nil; });
    class_addMethod(object_getClass(self), stubbedSEL, defaultStub, methodTypes);
    
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:methodTypes];
    IMP stubImp = imp_implementationWithBlock(stubBlockForSelectorWithMethodSignature(selector, signature));
    
    class_addMethod(object_getClass(self), selector, stubImp, methodTypes);
}

void createStubClass(id self)
{
    NSString *objectMetaClassName = [NSString stringWithFormat:@"%@%p", NSStringFromClass([self class]), self];
    Class objectMetaClass = objc_allocateClassPair(object_getClass(self), [objectMetaClassName UTF8String], 0);
    if (!objectMetaClass) [NSException raise:EverGreenStubException format:@"an error occurred when attempting to stub %@", self];
    
    objc_registerClassPair(objectMetaClass);
    object_setClass(self, objectMetaClass);
    objc_setAssociatedObject(self, isStubbedKey, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

# pragma mark - Stubbing

void stubSelectorForObject(SEL selector, id self)
{
    if (isSelectorStubbedForObject(selector, self)) return;
    if (!isStubbed(self)) objc_msgSend(self, NSSelectorFromString(@"_stub"));
    
    addSelectorToStubbedMethodListForObject(selector, self);
    addStubMethodForSelector(self, selector);
}

void stubSelectorForObjectAndCallThrough(SEL selector, id self)
{
    [self stub:selector];
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    Method unstubbedMethod = class_getInstanceMethod(class_getSuperclass(object_getClass(self)), selector);
    
    class_replaceMethod(object_getClass(self),
                        stubbedSEL,
                        method_getImplementation(unstubbedMethod),
                        method_getTypeEncoding(unstubbedMethod));
}

@implementation NSObject (EverGreen)

#pragma mark - Querying Stubbed Objects

- (BOOL)isStubbingMethod:(SEL)selector
{
    return [stubbedMethodsForObject(self) containsObject:NSStringFromSelector(selector)];
}

- (BOOL)isStubbingMethods
{
    return isStubbed(self);
}

#pragma mark - stub:

+ (void)stub:(SEL)selector
{
    stubSelectorForObject(selector, self);
}

+ (void)_stub
{
    createStubClass(self);
}

- (void)stub:(SEL)selector
{
    stubSelectorForObject(selector, self);
}

- (void)_stub
{
    createStubClass(self);
    
    Class originalClass = class_getSuperclass(object_getClass(self));
    IMP classIMP = imp_implementationWithBlock(^{ return originalClass; });
    class_addMethod(object_getClass(self), @selector(class), classIMP, "@@:");
}

#pragma mark - unstub:

- (void)unstub
{
    if (!isStubbed(self)) {
        [NSException raise:EverGreenStubException
                    format:@"You tried to unstub an instance that was never stubbed: %@", self];
    }
    
    Class StubClass = object_getClass(self);
    object_setClass(self, class_getSuperclass(StubClass));
    objc_disposeClassPair(StubClass);
    
    objc_setAssociatedObject(self, isStubbedKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, stubbedMethodsKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

#pragma mark - stubAndCallThrough:

- (void)stubAndCallThrough:(SEL)selector
{
    stubSelectorForObjectAndCallThrough(selector, self);
}

#pragma mark - stub:andReturn:

- (void)stub:(SEL)selector andReturn:(void *)returnValue
{
    [self stub:selector];
    
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    IMP stubbedIMP = imp_implementationWithBlock(^{ return returnValue; });
    Method unstubbedMethod = class_getInstanceMethod([self class], selector);
    
    class_replaceMethod(object_getClass(self),
                        stubbedSEL,
                        stubbedIMP,
                        method_getTypeEncoding(unstubbedMethod));
}

- (void)stub:(SEL)selector andCallFake:(id)block
{
    [self stub:selector];
    
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    IMP stubbedIMP = imp_implementationWithBlock(block);
    
    class_replaceMethod(object_getClass(self),
                        stubbedSEL,
                        stubbedIMP,
                        method_getTypeEncoding(class_getInstanceMethod([self class], selector)));
}

@end
