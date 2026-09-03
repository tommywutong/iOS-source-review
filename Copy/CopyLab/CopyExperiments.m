#import "CopyExperiments.h"

@interface CopyPerson : NSObject <NSCopying, NSMutableCopying>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger age;
@end

@implementation CopyPerson

- (id)copyWithZone:(NSZone *)zone {
    CopyPerson *copy = [[[self class] allocWithZone:zone] init];
    copy.name = self.name;
    copy.age = self.age;
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    // This model has no separate mutable subclass; the returned instance is
    // independently stored and can be changed through its writable properties.
    return [self copyWithZone:zone];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<CopyPerson: %p name=%@ age=%ld>",
            self, self.name, (long)self.age];
}

@end

@interface CopyBox : NSObject
@property (nonatomic, strong) NSMutableArray *strongArray;
@property (nonatomic, copy) NSMutableArray *copiedArray;
@end

@implementation CopyBox
@end

static void PrintResult(NSString *name, BOOL passed, NSString *detail) {
    NSLog(@"%@ %@ | %@", passed ? @"PASS" : @"FAIL", name, detail);
}

static NSString *ClassName(id object) {
    return object ? NSStringFromClass([object class]) : @"nil";
}

static id DeepCopyObject(id object);

static id DeepCopyObject(id object) {
    if ([object isKindOfClass:NSArray.class]) {
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:[object count]];
        for (id item in object) {
            [result addObject:DeepCopyObject(item) ?: NSNull.null];
        }
        return [result copy];
    }

    if ([object isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[object count]];
        for (id key in object) {
            id copiedKey = DeepCopyObject(key) ?: NSNull.null;
            id copiedValue = DeepCopyObject(object[key]) ?: NSNull.null;
            result[copiedKey] = copiedValue;
        }
        return [result copy];
    }

    if ([object isKindOfClass:NSSet.class]) {
        NSMutableSet *result = [NSMutableSet setWithCapacity:[object count]];
        for (id item in object) {
            [result addObject:DeepCopyObject(item) ?: NSNull.null];
        }
        return [result copy];
    }

    if ([object isKindOfClass:NSOrderedSet.class]) {
        NSMutableOrderedSet *result = [NSMutableOrderedSet orderedSetWithCapacity:[object count]];
        for (id item in object) {
            [result addObject:DeepCopyObject(item) ?: NSNull.null];
        }
        return [result copy];
    }

    if ([object conformsToProtocol:@protocol(NSCopying)]) {
        return [object copy];
    }

    return object;
}

static void ExperimentStringCopy(void) {
    NSMutableString *source = [NSMutableString stringWithString:@"Tom"];
    NSString *copy = [source copy];
    NSMutableString *mutableCopy = [source mutableCopy];

    PrintResult(@"E1 NSString copy is immutable",
                ![copy isKindOfClass:NSMutableString.class],
                [NSString stringWithFormat:@"copy=%@", ClassName(copy)]);
    PrintResult(@"E1 NSString mutableCopy is mutable",
                [mutableCopy isKindOfClass:NSMutableString.class],
                [NSString stringWithFormat:@"mutableCopy=%@", ClassName(mutableCopy)]);
}

static void ExperimentArrayShallowCopy(void) {
    NSMutableString *element = [NSMutableString stringWithString:@"Tom"];
    NSMutableArray *source = [NSMutableArray arrayWithObject:element];
    NSArray *copy = [source copy];

    BOOL outerIndependent = source != copy;
    BOOL elementShared = source[0] == copy[0];
    [element appendString:@" Wu"];
    NSString *elementAfterMutation = copy[0];

    PrintResult(@"E2 NSArray copy creates independent outer container",
                outerIndependent,
                [NSString stringWithFormat:@"source=%p copy=%p", source, copy]);
    PrintResult(@"E2 NSArray copy shares element objects",
                elementShared,
                [NSString stringWithFormat:@"source[0]=%p copy[0]=%p", source[0], copy[0]]);
    PrintResult(@"E2 mutating shared element affects shallow copy",
                [elementAfterMutation isEqualToString:@"Tom Wu"],
                [NSString stringWithFormat:@"copy[0]=%@", elementAfterMutation]);

    [source addObject:@"Other"];
    PrintResult(@"E2 mutating source container does not change copy container",
                copy.count == 1,
                [NSString stringWithFormat:@"source.count=%lu copy.count=%lu",
                 (unsigned long)source.count, (unsigned long)copy.count]);
}

static void ExperimentMutableCopy(void) {
    NSArray *source = @[@"A"];
    NSMutableArray *copy = [source mutableCopy];
    [copy addObject:@"B"];

    PrintResult(@"E3 mutableCopy returns mutable container",
                [copy isKindOfClass:NSMutableArray.class] && copy.count == 2,
                [NSString stringWithFormat:@"class=%@ count=%lu", ClassName(copy), (unsigned long)copy.count]);
}

static void ExperimentStrongVsCopy(void) {
    NSMutableArray *source = [NSMutableArray arrayWithObject:@"A"];
    CopyBox *box = [CopyBox new];
    box.strongArray = source;
    box.copiedArray = source;
    [source addObject:@"B"];

    PrintResult(@"E4 strong shares the original mutable container",
                box.strongArray.count == 2,
                [NSString stringWithFormat:@"strong.count=%lu", (unsigned long)box.strongArray.count]);
    PrintResult(@"E4 copy isolates the outer container",
                box.copiedArray.count == 1,
                [NSString stringWithFormat:@"copy.count=%lu class=%@",
                 (unsigned long)box.copiedArray.count, ClassName(box.copiedArray)]);

    BOOL runtimeTypeMismatch = ![box.copiedArray isKindOfClass:NSMutableArray.class];
    PrintResult(@"E4 copy NSMutableArray property can hold immutable runtime object",
                runtimeTypeMismatch,
                [NSString stringWithFormat:@"declared=NSMutableArray runtime=%@", ClassName(box.copiedArray)]);
}

static void ExperimentNSCopying(void) {
    CopyPerson *person = [CopyPerson new];
    person.name = @"Tom";
    person.age = 20;
    CopyPerson *copy = [person copy];
    CopyPerson *mutableCopy = [person mutableCopy];
    copy.name = @"Jerry";
    mutableCopy.name = @"Sam";

    PrintResult(@"E5 custom NSCopying object is independent",
                person != copy && [person.name isEqualToString:@"Tom"] && [copy.name isEqualToString:@"Jerry"],
                [NSString stringWithFormat:@"original=%@ copy=%@", person, copy]);
    PrintResult(@"E5 custom NSMutableCopying object is independent",
                person != mutableCopy && [person.name isEqualToString:@"Tom"] && [mutableCopy.name isEqualToString:@"Sam"],
                [NSString stringWithFormat:@"original=%@ mutableCopy=%@", person, mutableCopy]);
}

static void ExperimentNestedCopy(void) {
    NSMutableDictionary *inner = [@{ @"name": @"Tom" } mutableCopy];
    NSArray *source = @[ inner ];
    NSArray *shallow = [source copy];
    NSArray *deep = DeepCopyObject(source);

    inner[@"name"] = @"Jerry";

    PrintResult(@"E6 nested container copy is shallow",
                [shallow[0][@"name"] isEqualToString:@"Jerry"],
                [NSString stringWithFormat:@"shallow name=%@", shallow[0][@"name"]]);
    PrintResult(@"E6 recursive copy isolates nested mutable object",
                [deep[0][@"name"] isEqualToString:@"Tom"],
                [NSString stringWithFormat:@"deep name=%@", deep[0][@"name"]]);
}

static void ExperimentOtherContainers(void) {
    CopyPerson *person = [CopyPerson new];
    person.name = @"Tom";
    person.age = 20;

    NSSet *set = [NSSet setWithObject:person];
    NSSet *setCopy = [set copy];
    NSSet *setDeep = DeepCopyObject(set);

    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithObject:person];
    NSOrderedSet *orderedSetDeep = DeepCopyObject(orderedSet);

    PrintResult(@"E7 NSSet copy shares its element",
                [set anyObject] == [setCopy anyObject],
                [NSString stringWithFormat:@"original=%p copy=%p", [set anyObject], [setCopy anyObject]]);
    PrintResult(@"E7 NSSet recursive copy replaces its element",
                [set anyObject] != [setDeep anyObject],
                [NSString stringWithFormat:@"original=%p deep=%p", [set anyObject], [setDeep anyObject]]);
    PrintResult(@"E7 NSOrderedSet recursive copy preserves order and independence",
                orderedSet.count == orderedSetDeep.count && orderedSet.firstObject != orderedSetDeep.firstObject,
                [NSString stringWithFormat:@"source=%@ deep=%@", orderedSet, orderedSetDeep]);
}

void CopyExperimentsRun(void) {
    ExperimentStringCopy();
    ExperimentArrayShallowCopy();
    ExperimentMutableCopy();
    ExperimentStrongVsCopy();
    ExperimentNSCopying();
    ExperimentNestedCopy();
    ExperimentOtherContainers();
}
