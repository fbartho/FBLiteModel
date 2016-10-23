//
//  main.m
//  fbartho
//
//  Created by Frederic Barthelemy on 10/6/16.
//  Copyright © 2016 fbartho. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FBLiteModel.h"

@interface Sample: FBLiteModel
@property (atomic, readwrite, strong) NSString * nonDynamic;
@property (atomic, readwrite, strong) NSString * atomic;
@property (atomic, readwrite, strong) NSString * nonatomic;

@property (atomic, readwrite, copy) NSString * failPropCopy;
@property (atomic, readwrite, weak) NSString * failPropWeak;
@property (atomic, readwrite, strong, nonnull) NSString * nonnullProp;
@property (atomic, readwrite, strong, nonnull) NSString * nullableProp;
@property (atomic, readwrite, strong, null_resettable) NSString * nullResettableProp;
@property (atomic, readwrite, strong, null_unspecified) NSString * nullUnspecifiedProp;

@property (atomic, readwrite, strong) NSString * one;

@property (atomic, readwrite, assign, getter=isBOOL) BOOL BOOLProp;
@property (atomic, readwrite, assign) bool boolProp;

@property (atomic, readwrite, strong) NSURL * imageURL;
@property (atomic, readwrite, strong) NSNumber * _two_FooFF;

@property (atomic, readwrite, assign) int intProp;
@property (atomic, readwrite, assign) unsigned unsignedProp;
@property (atomic, readwrite, assign) long int longIntProp;
@property (atomic, readwrite, assign) long long longLongProp;
@property (atomic, readwrite, assign) long long int longLongIntProp;
@property (atomic, readwrite, assign) NSInteger NSIntegerProp;
@property (atomic, readwrite, assign) NSUInteger NSUIntegerProp;

@property (atomic, readwrite, assign) float floatProp;
@property (atomic, readwrite, assign) CGFloat cgfloatProp;
@property (atomic, readwrite, assign) CGSize sizeProp;
@property (atomic, readwrite, assign) CGRect rectProp;

@property (atomic, readwrite, strong) NSArray<NSString*>* stringArrayProp;
@end
@implementation Sample
@dynamic
	atomic, nonatomic, failPropCopy, failPropWeak, nonnullProp, nullableProp, nullResettableProp, nullUnspecifiedProp,

	one,

	BOOLProp, boolProp,

	imageURL, _two_FooFF,

	intProp, unsignedProp, longIntProp, longLongProp, longLongIntProp, NSIntegerProp, NSUIntegerProp,
	floatProp, cgfloatProp, sizeProp, rectProp,

	stringArrayProp;
@end
@interface Small: FBLiteModel
@property (atomic, readwrite, strong) NSString * one;
@end
@implementation Small
@dynamic one;
@end

@interface Sample (Two)
@property (atomic, readwrite, strong) NSString * two;
@end
@implementation Sample (Two)
@dynamic two;
@end

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		NSLog(@"Getter/Setter -> JSON Experiments");
		NSLog(@"imageURL: %@",[FBLiteModel fblm_jsonKeyForGetterName:@"imageURL"]);
		NSLog(@"setImageURL: %@",[FBLiteModel fblm_jsonKeyForSetterName:@"setImageURL"]);
		NSLog(@"isFoo: %@",[FBLiteModel fblm_jsonKeyForGetterName:@"isFoo"]);
		NSLog(@"_two_FooFF: %@",[FBLiteModel fblm_jsonKeyForGetterName:@"_two_FooFF"]);

//		Small* s1 = [[Small alloc] init];
//		NSLog(@"Small.one respondsTo: %@", [s1 respondsToSelector:@selector(one)] ? @YES: @NO);
//		NSLog(@"Small.one value: %@", s1.one);
		
		Sample* s2 = [Sample fblm_objectWithJSONFragment:@{
														   @"one": @"Sample!!",
														   @"two": @"Two??",
														   }];

		NSLog(@"Sample.one respondsTo: %@", [s2 respondsToSelector:@selector(one)] ? @YES: @NO);
		NSLog(@"Sample.one value: %@", s2.one);

		NSLog(@"Sample.two added through category? %@", s2.two);

		NSLog(@"Done");
	}
    return 0;
}
