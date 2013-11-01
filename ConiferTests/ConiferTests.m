#import <XCTest/XCTest.h>
#import "NSObject+Conifer.h"
#import <objc/message.h>

@interface TestObject : NSObject
- (NSString *)repeatString:(NSString *)string times:(NSUInteger)times;
- (void)voidRetVal;
- (NSUInteger)intRetVal;
@end

@implementation TestObject

+ (NSString *)classMethod
{
    return @"just a run of the mill class method";
}

- (NSString *)repeatString:(NSString *)string times:(NSUInteger)times
{
    NSMutableString *repeatedString = [@"" mutableCopy];
    for (NSUInteger i = 0; i < times; i++) {
        [repeatedString appendString:string];
    }
    
    return repeatedString;
}

- (void)voidRetVal
{
    return;
}

- (NSUInteger)intRetVal
{
    return 8;
}

@end

@interface ConiferTests : XCTestCase

@property (nonatomic, strong) TestObject *stubbed;
@property (nonatomic, strong) TestObject *anotherStubbedObject;
@property (nonatomic, strong) TestObject *unstubbed;

@end

@implementation ConiferTests

- (void)setUp
{
    [super setUp];
    
    self.stubbed = [TestObject new];
    self.anotherStubbedObject = [TestObject new];
    self.unstubbed = [TestObject new];
}

- (void)tearDown
{
    if ([self.stubbed isStubbingMethods]) [self.stubbed unstub];
    if ([self.anotherStubbedObject isStubbingMethods]) [self.anotherStubbedObject unstub];

    if ([TestObject isStubbingMethods]) [TestObject unstub];
    if ([TestObject isStubbingAnyInstanceMethods]) [TestObject anyInstanceUnstub];
    
    [super tearDown];
}

- (void)testStubbingDoesNotAffectUnstubbedInstances
{
    [self.stubbed stub:@selector(repeatString:times:)];
    [self.stubbed stub:@selector(voidRetVal)];
    [self.stubbed stub:@selector(intRetVal)];
    
    XCTAssert([[self.unstubbed repeatString:@"*" times:2] isEqualToString:@"**"],
              @"object return value not handled properly");
    
    XCTAssertNoThrow([self.unstubbed voidRetVal],
                     @"void return values not handled properly");
    
    XCTAssert([self.unstubbed intRetVal] == 8,
              @"primitive return value not handled properly");
}

- (void)testStubbingDefinesMethodReturningNilByDefault
{
    [self.stubbed stub:@selector(repeatString:times:)];
    XCTAssert(objc_msgSend(self.stubbed, NSSelectorFromString(@"_stubbedRepeatString:times:"), @"*", 2) == nil,
              @"stubbed method not returning nil");
}

- (void)testStubbingReturnsNilAsDefault
{
    [self.stubbed stub:@selector(repeatString:times:)];
    XCTAssert([self.stubbed repeatString:@"*" times:8] == nil,
              @"tubbed method not returning nil");
}

- (void)testStubbingAndCallingThrough
{
    [[self.stubbed stub:@selector(repeatString:times:)] andCallThrough];
    XCTAssert([[self.stubbed repeatString:@"*" times:2] isEqualToString:@"**"],
              @"stub and call through not returning original value");
}

- (void)testStubbingAndReturningObject
{
    [[self.stubbed stub:@selector(repeatString:times:)] andReturn:@"fake"];
    
    XCTAssert([[self.stubbed repeatString:@"*" times:2] isEqualToString:@"fake"],
              @"stub and return not properly returning given object");
}

- (void)testStubbingAndReturningPrimitive
{
    [[self.stubbed stub:@selector(intRetVal)] andReturn:(void *)32];
    
    XCTAssert([self.stubbed intRetVal] == 32,
              @"stub and return not properly returning given primitive");
}

- (void)testStubbingDoesNotAffectUnstubbedMethods
{
    [[self.stubbed stub:@selector(repeatString:times:)] andReturn:@"fake"];
    [[self.anotherStubbedObject stub:@selector(intRetVal)] andReturn:(void *)1000];
    
    XCTAssert([[self.anotherStubbedObject repeatString:@"*" times:2] isEqualToString:@"**"],
              @"unstubbed method returning stubbed value from other instance");
    
    XCTAssert([self.stubbed intRetVal] == 8,
              @"unstubbed method returning stubbed value from other instance");
}

- (void)testStubbingIsInstanceIndependent
{
    [[self.stubbed stub:@selector(repeatString:times:)] andReturn:@"fake"];
    [[self.anotherStubbedObject stub:@selector(repeatString:times:)] andReturn:@"faker"];
    
    XCTAssert([[self.stubbed repeatString:@"*" times:2] isEqualToString:@"fake"],
              @"stubbed value affected by stub on different instance");
    
    XCTAssert([[self.anotherStubbedObject repeatString:@"*" times:2] isEqualToString:@"faker"],
              @"stubbed value affected by stub on different instance");
}

- (void)testStubbingAndCallingFake
{
    [[self.stubbed stub:@selector(repeatString:times:)] andCallFake:
     ^NSString* (TestObject *me, NSString *string, NSUInteger times) {
         return @"fake";
     }];
    
    XCTAssert([[self.stubbed repeatString:@"*" times:2] isEqualToString:@"fake"],
              @"stub and call fake not invoking fake block");
}

- (void)testStubbingAndCallingFakeWithIncompleteArguments
{
    [[self.stubbed stub:@selector(repeatString:times:)] andCallFake:
     ^{
         return @"no args";
     }];
    XCTAssert([[self.stubbed repeatString:@"*" times:2] isEqualToString:@"no args"],
              @"stub and call fake with block with no arguments failed");
    
    
    [[self.stubbed stub:@selector(repeatString:times:)] andCallFake:
     ^id (TestObject *me) {
         return me;
     }];
    
    XCTAssert((id)[self.stubbed repeatString:@"*" times:2] == self.stubbed,
              @"stub and call fake with block with fewer arguments than method failed");
}

- (void)testUnstub
{
    [[self.stubbed stub:@selector(repeatString:times:)] andCallFake:
     ^NSString* (TestObject *me, NSString *string, NSUInteger times) {
         return @"fake";
     }];
    
    [self.stubbed unstub];
    XCTAssert([[self.stubbed repeatString:@"*" times:2] isEqualToString:@"**"],
              @"unstubbing stubbed object not restoring original behavior");
}

- (void)testStubbingThenUnstubbingThenReStubbingDoesNotThrowErrors
{
    [self.stubbed stub:@selector(repeatString:times:)];
    [self.stubbed unstub];
    
    XCTAssertNoThrow([self.stubbed stub:@selector(intRetVal)],
                     @"stubbing instance after unstubbing it throws an error");
}

- (void)testUnstubThrowsErrorForInstanceThatIsNotStubbed
{
    XCTAssertThrows([self.unstubbed unstub],
                    @"unstubbing instance that was never stubbed did not cause an exception");
}

- (void)testStubReturnsOriginalClass
{
    [[self.stubbed stub:@selector(intRetVal)] andReturn:(void *)1000];
    
    XCTAssert([self.stubbed class] == [TestObject class],
              @"stubbed object doesn't return original class");
    
    XCTAssert([self.stubbed isMemberOfClass:[TestObject class]],
              @"stubbed object doesn't return original class");
}

- (void)testInstancesCanBeQueriedAboutStubs
{
    [self.stubbed stub:@selector(intRetVal)];
    XCTAssertTrue([self.stubbed isStubbingMethods],
                  @"stubbed instance returning false for hasStubbedMethods");
    
    XCTAssertTrue([self.stubbed isStubbingMethod:@selector(intRetVal)],
                  @"instance stubbing method returning false for isStubbingMethod");
    
    XCTAssertFalse([self.stubbed isStubbingMethod:@selector(voidRetVal)],
                  @"instance not stubbing method returning true for isStubbingMethod");
}

- (void)testClassMethodsCanBeStubbed
{
    [TestObject stub:@selector(classMethod)];
    XCTAssert([TestObject classMethod] == nil,
              @"class method was not stubbed");
}

- (void)testClassMethodsCanBeUnStubbed
{
    NSString *originalReturnValue = [TestObject classMethod];
    [TestObject stub:@selector(classMethod)];
    [TestObject unstub];
    
    XCTAssert([[TestObject classMethod] isEqualToString:originalReturnValue],
              @"class method not restored after unstubbing");
}

- (void)testClassMethodStubbingAndCallingThrough
{
    NSString *originalReturnValue = [TestObject classMethod];
    [[TestObject stub:@selector(classMethod)] andCallThrough];
    XCTAssert([[TestObject classMethod] isEqualToString:originalReturnValue],
              @"stub and call through not returning original value");
}

- (void)testClassMethodStubbingAndReturning
{
    [[TestObject stub:@selector(classMethod)] andReturn:@"faked out"];
    XCTAssert([[TestObject classMethod] isEqualToString:@"faked out"],
              @"stub andReturn not returning given value");
}

- (void)testClassMethodStubbingAndCallingFake
{
    [[TestObject stub:@selector(classMethod)] andCallFake:^NSString* (id me){
        return [NSString stringWithFormat:@"%@ fake", NSStringFromClass(me)];
    }];
    
    XCTAssert([[TestObject classMethod] isEqualToString:@"TestObject fake"],
              @"stub andCallFake not returning value from given block");
}

- (void)testClassesCanBeQueriedAboutStubs
{
    [TestObject stub:@selector(classMethod)];
    XCTAssertTrue([TestObject isStubbingMethods],
                  @"stubbed instance returning false for hasStubbedMethods");
    
    XCTAssertTrue([TestObject isStubbingMethod:@selector(classMethod)],
                  @"instance stubbing method returning false for isStubbingMethod");
    
    XCTAssertFalse([TestObject isStubbingMethod:@selector(class)],
                   @"instance not stubbing method returning true for isStubbingMethod");
}

- (void)testStubbedClassReturnSameClassAsBefore
{
    [TestObject stub:@selector(classMethod)];
    
    XCTAssert([self.stubbed class] == [TestObject class],
              @"+class does not return same value as stubbed instance -class");
    
    XCTAssert([self.unstubbed class] == [TestObject class],
              @"+class does not return same value as unstubbed instance -class");
}

- (void)testStubbingAnyInstance
{
    [TestObject anyInstanceStub:@selector(repeatString:times:)];
    
    XCTAssert([self.unstubbed repeatString:@"blah" times:100] == nil,
              @"Any instance stub did not work");
    
    XCTAssertTrue([TestObject isStubbingAnyInstanceMethods],
                  @"anyInstance stubs not reported");
    XCTAssertFalse([TestObject isStubbingAnyInstanceMethod:@selector(intRetVal)],
                   @"anyInstance stubs not reported");
    XCTAssertTrue([TestObject isStubbingAnyInstanceMethod:@selector(repeatString:times:)],
                  @"anyInstance stubs not reported");
}

- (void)testUnstubbingOneAnyInstanceMethod
{
    [TestObject anyInstanceStub:@selector(repeatString:times:)];
    [TestObject anyInstanceUnstub:@selector(repeatString:times:)];
    
    XCTAssert([[self.unstubbed repeatString:@"*" times:1] isEqualToString:@"*"],
              @"Any instance unstub did not work");
    XCTAssertFalse([TestObject isStubbingAnyInstanceMethod:@selector(repeatString:times:)],
                   @"Did not remove selector from the list of stubbed methods");
}

- (void)testUnstubbingAllAnyInstanceMethods
{
    [TestObject anyInstanceStub:@selector(repeatString:times:)];
    [TestObject anyInstanceUnstub];
    
    XCTAssert([[self.unstubbed repeatString:@"*" times:1] isEqualToString:@"*"],
              @"Any instance unstub did not work");
}

@end
