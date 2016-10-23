//
//  FBLiteModel.h
//  fbartho
//
//  Created by Frederic Barthelemy on 10/6/16.
//  Copyright © 2016 fbartho. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBLiteModel : NSObject

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithJSONDictionary:(NSDictionary<NSString*, id>*)dictionary;

+ (NSArray<__kindof FBLiteModel*>*)objectsWithArray:(nullable NSArray<NSDictionary<NSString*, id>*>*)array;
@end

#pragma mark - Nullability
/// Implement this protocol if you have a nonnull property, and you want to return a default value instead. (Is also used in null_resettable cases)
@protocol FBLiteModelNullability <NSObject>
+ (id)fblm_nonnullPropertyNilReplacement;
@end
@interface NSNumber (FBLiteModelNullability) <FBLiteModelNullability> @end
@interface NSString (FBLiteModelNullability) <FBLiteModelNullability> @end
@interface NSArray (FBLiteModelNullability) <FBLiteModelNullability>  @end
@interface NSDictionary (FBLiteModelNullability) <FBLiteModelNullability> @end

typedef NS_OPTIONS(NSUInteger, FBLiteModelNullabilityType) {
	FBLiteModelNullable = 0,

	FBLiteModelNonnullAssignFlag = 0b01,
	FBLiteModelNonnullReturnFlag = 0b10,

	FBLiteModelNonnull = (FBLiteModelNonnullReturnFlag | FBLiteModelNonnullAssignFlag),
	FBLiteModelNullResettable = (FBLiteModelNonnullReturnFlag)
};
@interface FBLiteModel ()
+ (BOOL)hintProperty:(NSString*)propertyName nullability:(FBLiteModelNullabilityType)type;
+ (BOOL)hintProperty:(NSString*)propertyName nullability:(FBLiteModelNullabilityType)type defaultValue:(id)value;
@end

#pragma mark - Collections
@protocol FBLiteModelCollection
@end
@interface FBLiteModel ()
+ (BOOL)hintCollectionFactory:(id<FBLiteModelCollection>)collectionFactory forProperty:(NSString*)propertyName;

+ (id)arrayCollectionFactoryForType:(Class)fbLiteModelSubclass;
/// Produces a factory that generates [String:fbLiteModelSubclass] when parsed.
+ (id)dictionaryCollectionFactoryForType:(Class)fbLiteModelSubclass;
+ (id)dictionaryCollectionFactoryForType:(Class)fbLiteModelSubclass keyType:(id<NSCopying>)keyType;
@end
/// This is the assumed type of any NSArray properties, that have not been otherwise hinted a collection factory
/// - It just passes through the nested JSON array
extern id<FBLiteModelCollection> FBLiteModelJSONTypeArrayCollectionFactory;
/// This is the assumed type of any NSDictionary properties, that have not been otherwise hinted a collection factory
/// - It just passes through the nested JSON dictionary
extern id<FBLiteModelCollection> FBLiteModelJSONTypeDictionaryCollectionFactory;

/// FBLiteModel Semi-public Internals
@interface FBLiteModel ()
@property (nonatomic, readonly, strong, nullable) NSDictionary<NSString*, id>* fblm_original;
@property (nonatomic, readonly, strong, nonnull) NSMutableDictionary<NSString*, id>* fblm_storage;
@end

#pragma mark - | Implementors API |

@interface FBLiteModel ()
/// Name mangling from fooBarBaz -> foo_bar_baz
+ (NSString*)fblm_jsonKeyForGetterName:(NSString*)getterName;
/// Name mangling from setFooBarBaz -> foo_bar_baz
+ (NSString*)fblm_jsonKeyForSetterName:(NSString*)getterName;
/// Take a runtime type-encoding (that looks like `@"ClassName"`) and turns it into a reference to the class.
+ (nullable Class)fblm_parseClassFromTypeEncoding:(NSString*)tEncoding;
@end

#pragma mark - Construction
@protocol FBLiteModelConstruction
/// Produces objects when passed a JSON Fragment
+ (nullable id)fblm_objectWithJSONFragment:(nullable NSObject*)fragment;
@end
@interface NSNumber (FBLiteModelConstruction) <FBLiteModelConstruction> @end
@interface NSString (FBLiteModelConstruction) <FBLiteModelConstruction> @end
//@interface NSArray (FBLiteModelConstruction) <FBLiteModelConstruction> @end
//@interface NSDictionary (FBLiteModelConstruction) <FBLiteModelConstruction> @end
@interface FBLiteModel (FBLiteModelConstruction) <FBLiteModelConstruction> @end

@protocol FBLiteModelInstallObjectTypeProperty
+ (BOOL)fblm_installFBLMPropertyGetter:(NSString*)propName
							  selector:(SEL)sel
								atomic:(BOOL)atomic
							isNullable:(BOOL)isNullable
						nullResettable:(BOOL)nullResettable
							  forClass:(Class)targetClass;
+ (BOOL)fblm_installFBLMPropertySetter:(NSString*)propName
							  selector:(SEL)sel
								atomic:(BOOL)atomic
							isNullable:(BOOL)isNullable
						nullResettable:(BOOL)nullResettable
							  forClass:(Class)targetClass;
// also must implement noop methods for the following
// - (nullable instancetype)fblm_canonicalTypeEncodingForGetter;
// - (void)fblm_canonicalTypeEncodingForSetter:(nullable instancetype)arg;
@end
@interface NSString (FBLiteModelInstallObjectTypeProperty) <FBLiteModelInstallObjectTypeProperty> @end
@interface NSNumber (FBLiteModelInstallObjectTypeProperty) <FBLiteModelInstallObjectTypeProperty> @end
@interface FBLiteModel (FBLiteModelInstallObjectTypeProperty) <FBLiteModelInstallObjectTypeProperty> @end

#ifndef FBLiteModelNilReplacement
/// This is the value used internally
#define FBLiteModelNilReplacement ((id)[NSNull null])
#endif


NS_ASSUME_NONNULL_END
