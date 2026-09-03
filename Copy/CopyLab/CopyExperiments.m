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

static void ExperimentCopyMatrix(void) {
    // The four rows in the reference table are tested first with strings,
    // where independence means that the copied value is stored separately.
    NSMutableString *mutableString = [NSMutableString stringWithString:@"mutable"];
    NSString *mutableStringCopy = [mutableString copy];
    NSMutableString *mutableStringMutableCopy = [mutableString mutableCopy];

    NSString *immutableString = [NSString stringWithFormat:@"%@", @"immutable"];
    NSString *immutableStringCopy = [immutableString copy];
    NSMutableString *immutableStringMutableCopy = [immutableString mutableCopy];

    [mutableString appendString:@"-source"];
    [mutableStringMutableCopy appendString:@"-copy"];
    [immutableStringMutableCopy appendString:@"-copy"];

    PrintResult(@"E8 mutable object + copy -> immutable independent",
                ![mutableStringCopy isKindOfClass:NSMutableString.class] &&
                    mutableStringCopy != mutableString &&
                    [mutableStringCopy isEqualToString:@"mutable"],
                [NSString stringWithFormat:@"source=%p copy=%p class=%@ value=%@",
                 mutableString, mutableStringCopy, ClassName(mutableStringCopy), mutableStringCopy]);
    PrintResult(@"E8 mutable object + mutableCopy -> mutable independent",
                [mutableStringMutableCopy isKindOfClass:NSMutableString.class] &&
                    mutableStringMutableCopy != mutableString &&
                    [mutableStringMutableCopy isEqualToString:@"mutable-copy"],
                [NSString stringWithFormat:@"source=%p copy=%p class=%@ value=%@",
                 mutableString, mutableStringMutableCopy, ClassName(mutableStringMutableCopy), mutableStringMutableCopy]);
    PrintResult(@"E8 immutable object + copy -> immutable",
                ![immutableStringCopy isKindOfClass:NSMutableString.class] &&
                    [immutableStringCopy isEqualToString:@"immutable"],
                [NSString stringWithFormat:@"source=%p copy=%p same=%@ class=%@",
                 immutableString, immutableStringCopy,
                 immutableString == immutableStringCopy ? @"YES" : @"NO",
                 ClassName(immutableStringCopy)]);
    PrintResult(@"E8 immutable object + mutableCopy -> mutable independent",
                [immutableStringMutableCopy isKindOfClass:NSMutableString.class] &&
                    immutableStringMutableCopy != immutableString &&
                    [immutableStringMutableCopy isEqualToString:@"immutable-copy"],
                [NSString stringWithFormat:@"source=%p copy=%p class=%@ value=%@",
                 immutableString, immutableStringMutableCopy,
                 ClassName(immutableStringMutableCopy), immutableStringMutableCopy]);

    // For containers, copy depth is observable through a mutable nested
    // element. Foundation copies the outer container but normally shares it.
    NSMutableString *mutableElementForCopy = [NSMutableString stringWithString:@"element"];
    NSMutableArray *mutableArrayForCopy = [NSMutableArray arrayWithObject:mutableElementForCopy];
    NSArray *mutableArrayCopy = [mutableArrayForCopy copy];
    [mutableElementForCopy appendString:@"-changed"];

    NSMutableString *mutableElementForMutableCopy = [NSMutableString stringWithString:@"element"];
    NSMutableArray *mutableArrayForMutableCopy = [NSMutableArray arrayWithObject:mutableElementForMutableCopy];
    NSMutableArray *mutableArrayMutableCopy = [mutableArrayForMutableCopy mutableCopy];
    [mutableElementForMutableCopy appendString:@"-changed"];

    NSMutableString *immutableElementForCopy = [NSMutableString stringWithString:@"element"];
    NSArray *immutableArrayForCopy = @[ immutableElementForCopy ];
    NSArray *immutableArrayCopy = [immutableArrayForCopy copy];
    [immutableElementForCopy appendString:@"-changed"];

    NSMutableString *immutableElementForMutableCopy = [NSMutableString stringWithString:@"element"];
    NSArray *immutableArrayForMutableCopy = @[ immutableElementForMutableCopy ];
    NSMutableArray *immutableArrayMutableCopy = [immutableArrayForMutableCopy mutableCopy];
    [immutableElementForMutableCopy appendString:@"-changed"];

    PrintResult(@"E9 mutable container + copy -> immutable outer, inner shared",
                ![mutableArrayCopy isKindOfClass:NSMutableArray.class] &&
                    mutableArrayCopy != mutableArrayForCopy &&
                    mutableArrayCopy[0] == mutableElementForCopy &&
                    [mutableArrayCopy[0] isEqualToString:@"element-changed"],
                [NSString stringWithFormat:@"outerSame=%@ innerSame=%@ class=%@ value=%@",
                 mutableArrayForCopy == mutableArrayCopy ? @"YES" : @"NO",
                 mutableArrayForCopy[0] == mutableArrayCopy[0] ? @"YES" : @"NO",
                 ClassName(mutableArrayCopy), mutableArrayCopy[0]]);
    PrintResult(@"E9 mutable container + mutableCopy -> mutable outer, inner shared",
                [mutableArrayMutableCopy isKindOfClass:NSMutableArray.class] &&
                    mutableArrayMutableCopy != mutableArrayForMutableCopy &&
                    mutableArrayMutableCopy[0] == mutableElementForMutableCopy &&
                    [mutableArrayMutableCopy[0] isEqualToString:@"element-changed"],
                [NSString stringWithFormat:@"outerSame=%@ innerSame=%@ class=%@ value=%@",
                 mutableArrayForMutableCopy == mutableArrayMutableCopy ? @"YES" : @"NO",
                 mutableArrayForMutableCopy[0] == mutableArrayMutableCopy[0] ? @"YES" : @"NO",
                 ClassName(mutableArrayMutableCopy), mutableArrayMutableCopy[0]]);
    PrintResult(@"E9 immutable container + copy -> immutable outer, inner shared",
                ![immutableArrayCopy isKindOfClass:NSMutableArray.class] &&
                    immutableArrayCopy[0] == immutableElementForCopy &&
                    [immutableArrayCopy[0] isEqualToString:@"element-changed"],
                [NSString stringWithFormat:@"outerSame=%@ innerSame=%@ class=%@ value=%@",
                 immutableArrayForCopy == immutableArrayCopy ? @"YES" : @"NO",
                 immutableArrayForCopy[0] == immutableArrayCopy[0] ? @"YES" : @"NO",
                 ClassName(immutableArrayCopy), immutableArrayCopy[0]]);
    PrintResult(@"E9 immutable container + mutableCopy -> mutable outer, inner shared",
                [immutableArrayMutableCopy isKindOfClass:NSMutableArray.class] &&
                    immutableArrayMutableCopy != immutableArrayForMutableCopy &&
                    immutableArrayMutableCopy[0] == immutableElementForMutableCopy &&
                    [immutableArrayMutableCopy[0] isEqualToString:@"element-changed"],
                [NSString stringWithFormat:@"outerSame=%@ innerSame=%@ class=%@ value=%@",
                 immutableArrayForMutableCopy == immutableArrayMutableCopy ? @"YES" : @"NO",
                 immutableArrayForMutableCopy[0] == immutableArrayMutableCopy[0] ? @"YES" : @"NO",
                 ClassName(immutableArrayMutableCopy), immutableArrayMutableCopy[0]]);
}

void CopyExperimentsRun(void) {
    ExperimentStringCopy();
    ExperimentArrayShallowCopy();
    ExperimentMutableCopy();
    ExperimentStrongVsCopy();
    ExperimentNSCopying();
    ExperimentNestedCopy();
    ExperimentOtherContainers();
    ExperimentCopyMatrix();
}
