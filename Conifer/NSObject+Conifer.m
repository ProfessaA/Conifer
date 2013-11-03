#import "NSObject+Conifer.h"
#import <objc/runtime.h>
#import <objc/message.h>

NSString * const ConiferStubException = @"ConiferStubException";

static const char *stubbedMethodsKey = "stubbedMethodsKey";
static const char *isStubbedKey = "isStubbedKey";
static const char *withArgumentsKey = "withArgumentsKey";

@interface NSObject (ConiferPrivate)

- (NSMutableDictionary *)stubbedMethods;

@end

#pragma mark - Helper Functions

SEL stubbedSelectorForSelector(SEL selector)
{
    NSString *selectorString = NSStringFromSelector(selector);
    selectorString = [selectorString stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                                             withString:[[selectorString substringToIndex:1] uppercaseString]];
    return NSSelectorFromString([@"_stubbed" stringByAppendingString:selectorString]);
}

SEL stubbedSelectorForSelectorWithArgumentsIndex(SEL selector, NSUInteger withArgumentsIndex)
{
    NSString *selectorString = NSStringFromSelector(selector);
    selectorString = [selectorString stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                                             withString:[[selectorString substringToIndex:1] uppercaseString]];
    return NSSelectorFromString([@"_stubbed" stringByAppendingFormat:@"_%d_%@", withArgumentsIndex, selectorString]);
}

SEL originalMethodSelectorForSelector(SEL selector)
{
    NSString *selectorString = NSStringFromSelector(selector);
    selectorString = [selectorString stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                                             withString:[[selectorString substringToIndex:1] uppercaseString]];
    return NSSelectorFromString([@"_original" stringByAppendingString:selectorString]);
}

NSMutableArray * withArgumentsArray(id me)
{
    return objc_getAssociatedObject(me, withArgumentsKey);
}

id stubBlockForSelectorWithMethodSignature(SEL selector, NSMethodSignature *signature)
{
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    return ^void* (id me, ...) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setSelector:stubbedSEL];
        
        NSMutableArray *receivedArguments = [@[] mutableCopy];
        
        va_list args;
        va_start(args, me);
        NSUInteger numArguments = [signature numberOfArguments];
        for (int i = 2; i < numArguments; i++) {
            void *arg = va_arg(args, void *);
            [invocation setArgument:&arg atIndex:i];
            [receivedArguments addObject:[NSValue value:&arg
                                           withObjCType:[signature getArgumentTypeAtIndex:i]]];
        }
        va_end(args);
        
        [[me stubbedMethods][NSStringFromSelector(selector)] addObject:receivedArguments];
        
        if (withArgumentsArray(me).count) {
            __block NSUInteger matchedArgumentsIndex = NSNotFound;
            [withArgumentsArray(me) enumerateObjectsUsingBlock:^(NSArray *withArguments, NSUInteger idx, BOOL *stop) {
                if ([receivedArguments isEqual:withArguments]) {
                    matchedArgumentsIndex = idx;
                    *stop = YES;
                }
            }];
            
            if (matchedArgumentsIndex != NSNotFound) {
                [invocation setSelector:stubbedSelectorForSelectorWithArgumentsIndex(selector, matchedArgumentsIndex)];
            }
        }
        
        [invocation invokeWithTarget:me];
        
        void *retVal;
        [invocation getReturnValue:&retVal];
        return strcmp([signature methodReturnType], "v") == 0 ? nil : retVal;
    };
}

void stubSelectorFromSourceClassOnDestinationClass(SEL selector, Class sourceClass, Class destinationClass)
{
    Method originalMethod = class_getInstanceMethod(sourceClass, selector);
    const char *methodTypes = method_getTypeEncoding(originalMethod);
    
    SEL stubbedSEL = stubbedSelectorForSelector(selector);
    IMP defaultStub = imp_implementationWithBlock(^ { return nil; });
    class_addMethod(destinationClass, stubbedSEL, defaultStub, methodTypes);
    
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:methodTypes];
    IMP stubIMP = imp_implementationWithBlock(stubBlockForSelectorWithMethodSignature(selector, signature));
    class_replaceMethod(destinationClass, selector, stubIMP, methodTypes);
}

@implementation NSObject (Conifer)

#pragma mark - Querying Stubbed Objects

- (BOOL)isStubbingMethod:(SEL)selector
{
    return [self stubbedMethods][NSStringFromSelector(selector)] != nil;
}

- (BOOL)isStubbingMethods
{
    return [objc_getAssociatedObject(self, isStubbedKey) boolValue];
}

- (BOOL)didReceive:(SEL)selector
{
    return [[self stubbedMethods][NSStringFromSelector(selector)] count] > 0;
}

#pragma mark - Creating Initial Stub

- (CONStub *)stub:(SEL)selector
{
    if (![self isStubbingMethod:selector]) {
        if (![self isStubbingMethods]) [self _stub];
        
        [self stubbedMethods][NSStringFromSelector(selector)] = [@[] mutableCopy];
        
        stubSelectorFromSourceClassOnDestinationClass(selector,
                                                      class_getSuperclass(object_getClass(self)),
                                                      object_getClass(self));
        
    }
    
    return [[CONStub alloc] initWithObject:self
                          originalSelector:selector
                              stubSelector:stubbedSelectorForSelector(selector)];
}

+ (void)_stub
{
    [self createStubClass];
}

- (void)_stub
{
    [self createStubClass];
    
    Class originalClass = class_getSuperclass(object_getClass(self));
    IMP classIMP = imp_implementationWithBlock(^{ return originalClass; });
    class_addMethod(object_getClass(self), @selector(class), classIMP, "@@:");
}

- (CONStub *)stub:(SEL)selector with:(void *)firstArgument, ...
{
    CONStub *defaultStub = [self stub:selector];
    Class stubClass = object_getClass(self);
    Class originalClass = class_getSuperclass(stubClass);
    
    Method originalMethod = class_getInstanceMethod(originalClass, selector);
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(originalMethod)];
    
    NSMutableArray *withArguments = [@[] mutableCopy];
    va_list args;
    va_start(args, firstArgument);
    [withArguments addObject:[NSValue value:&firstArgument
                               withObjCType:[signature getArgumentTypeAtIndex:2]]];

    NSUInteger numArguments = [signature numberOfArguments];
    for (int i = 3; i < numArguments; i++) {
        void *arg = va_arg(args, void *);
        [withArguments addObject:[NSValue value:&arg
                                   withObjCType:[signature getArgumentTypeAtIndex:i]]];
    }
    va_end(args);
    
    NSUInteger withArgIndex = withArgumentsArray(self).count;
    [withArgumentsArray(self) addObject:withArguments];
    
    [defaultStub andCallFake:^{
        [NSException raise:@"Unexpected arguments" format:@"%@", NSStringFromSelector(selector)];
        return nil;
    }];
    
    CONStub *withArgumentsStub = [[CONStub alloc] initWithObject:self
                                                originalSelector:selector
                                                    stubSelector:stubbedSelectorForSelectorWithArgumentsIndex(selector, withArgIndex)];
    
    [withArgumentsStub andCallFake:^{ return nil; }];
    
    return withArgumentsStub;
}

#pragma mark - Unstubbing

- (void)unstub
{
    if (![self isStubbingMethods]) {
        [NSException raise:ConiferStubException
                    format:@"You tried to unstub an instance that was never stubbed: %@", self];
    }
    
    Class StubClass = object_getClass(self);
    object_setClass(self, class_getSuperclass(StubClass));
    objc_disposeClassPair(StubClass);
    
    objc_setAssociatedObject(self, isStubbedKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, stubbedMethodsKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, withArgumentsKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

# pragma mark - Private

- (NSMutableDictionary *)stubbedMethods
{
    return objc_getAssociatedObject(self, stubbedMethodsKey);
}

- (void)createStubClass
{
    NSString *objectMetaClassName = [NSString stringWithFormat:@"%@%p", NSStringFromClass([self class]), self];
    Class objectMetaClass = objc_allocateClassPair(object_getClass(self), [objectMetaClassName UTF8String], 0);
    if (!objectMetaClass) [NSException raise:ConiferStubException format:@"an error occurred when attempting to stub %@", self];
    
    objc_registerClassPair(objectMetaClass);
    object_setClass(self, objectMetaClass);
    objc_setAssociatedObject(self, isStubbedKey, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, stubbedMethodsKey, [@{} mutableCopy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, withArgumentsKey, [@[] mutableCopy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
