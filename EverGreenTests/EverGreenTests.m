#import <XCTest/XCTest.h>
#import "NSObject+EverGreen.h"
#import <objc/message.h>

@interface TestObject : NSObject
- (NSString *)repeatString:(NSString *)string times:(NSUInteger)times;
- (void)voidRetVal;
- (NSUInteger)intRetVal;
@end

@implementation TestObject

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

@interface EverGreenTests : XCTestCase

@end

@implementation EverGreenTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testStubbingDoesNotAffectUnstubbedInstances
{
    TestObject *unstubbed = [TestObject new];
    TestObject *stubbed = [TestObject new];
    
    [stubbed stub:@selector(repeatString:times:)];
    [stubbed stub:@selector(voidRetVal)];
    [stubbed stub:@selector(intRetVal)];
    
    XCTAssert([[unstubbed repeatString:@"*" times:2] isEqualToString:@"**"],
              @"object return value not handled properly");
    
    XCTAssertNoThrow([unstubbed voidRetVal],
                     @"void return values not handled properly");
    
    XCTAssert([unstubbed intRetVal] == 8,
              @"primitive return value not handled properly");
}

- (void)testStubbingDoesNotAffectUnstubbedMethods
{
    TestObject *stubbed1 = [TestObject new];
    TestObject *stubbed2 = [TestObject new];
    
    [stubbed1 stub:@selector(repeatString:times:) andReturn:@"fake"];
    [stubbed2 stub:@selector(intRetVal) andReturn:(void *)1000];
    
    XCTAssert([[stubbed2 repeatString:@"*" times:2] isEqualToString:@"**"],
              @"unstubbed method returning stubbed value from other instance");
    
    XCTAssert([stubbed1 intRetVal] == 8,
              @"unstubbed method returning stubbed value from other instance");
}

- (void)testStubbingIsInstanceIndependent
{
    TestObject *stubbed1 = [TestObject new];
    TestObject *stubbed2 = [TestObject new];
    
    [stubbed1 stub:@selector(repeatString:times:) andReturn:@"fake"];
    [stubbed2 stub:@selector(repeatString:times:) andReturn:@"faker"];
    
    XCTAssert([[stubbed1 repeatString:@"*" times:2] isEqualToString:@"fake"],
              @"stubbed value affected by stub on different instance");
    
    XCTAssert([[stubbed2 repeatString:@"*" times:2] isEqualToString:@"faker"],
              @"stubbed value affected by stub on different instance");
}

- (void)testStubbingDefinesMethodReturningNilByDefault
{
    TestObject *stubbed = [TestObject new];
    
    [stubbed stub:@selector(repeatString:times:)];
    XCTAssert(objc_msgSend(stubbed, NSSelectorFromString(@"_stubbedRepeatString:times:"), @"*", 2) == nil,
              @"stubbed method not returning nil");
}

- (void)testStubbingReturnsNilAsDefault
{
    TestObject *stubbed = [TestObject new];
    
    [stubbed stub:@selector(repeatString:times:)];
    XCTAssert([stubbed repeatString:@"*" times:8] == nil,
              @"tubbed method not returning nil");
}

- (void)testStubbingAndCallingThrough
{
    TestObject *stubbed = [TestObject new];
    
    [stubbed stubAndCallThrough:@selector(repeatString:times:)];
    XCTAssert([[stubbed repeatString:@"*" times:2] isEqualToString:@"**"],
              @"stub and call through not returning original value");
}

- (void)testStubbingAndReturningObject
{
    TestObject *stubbed = [TestObject new];
    
    [stubbed stub:@selector(repeatString:times:) andReturn:@"fake"];
    
    XCTAssert([[stubbed repeatString:@"*" times:2] isEqualToString:@"fake"],
              @"stub and return not properly returning given object");
}

- (void)testStubbingAndReturningPrimitive
{
    TestObject *stubbed = [TestObject new];
    
    [stubbed stub:@selector(intRetVal) andReturn:(void *)32];
    
    XCTAssert([stubbed intRetVal] == 32,
              @"stub and return not properly returning given primitive");
}

- (void)testStubbingAndCallingFake
{
    TestObject *stubbed = [TestObject new];
    
    [stubbed stub:@selector(repeatString:times:) andCallFake:
     ^NSString* (TestObject *me, NSString *string, NSUInteger times) {
         return @"fake";
     }];
    
    XCTAssert([[stubbed repeatString:@"*" times:2] isEqualToString:@"fake"],
              @"stub and call fake not invoking fake block");
}

- (void)testUnstub
{
    TestObject *stubbed = [TestObject new];
    
    [stubbed stub:@selector(repeatString:times:) andCallFake:
     ^NSString* (TestObject *me, NSString *string, NSUInteger times) {
         return @"fake";
     }];
    
    [stubbed unstub];
    XCTAssert([[stubbed repeatString:@"*" times:2] isEqualToString:@"**"],
              @"unstubbing stubbed object not restoring original behavior");
}

- (void)testStubReturnsOriginalClass
{
    TestObject *stubbed = [TestObject new];
    
    [stubbed stub:@selector(intRetVal) andReturn:(void *)1000];
    XCTAssert([stubbed class] == [TestObject class],
              @"stubbed object doesn't return original class");
    
    XCTAssert([stubbed isMemberOfClass:[TestObject class]],
              @"stubbed object doesn't return original class");
}

@end
