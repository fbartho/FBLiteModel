//
//  FBLiteModel.m
//  fbartho
//
//  Created by Frederic Barthelemy on 10/6/16.
//  Copyright © 2016 fbartho. All rights reserved.
//

#import <objc/runtime.h>

#import "FBLiteModel.h"

static NSArray<Class> *FBLM_supportedMappingBaseTypes = nil;

@implementation FBLiteModel
@synthesize fblm_original;
@synthesize fblm_storage;
+ (void)load {
	FBLM_supportedMappingBaseTypes = @[
									   NSString.class,
									   NSNumber.class,
									   FBLiteModel.class,
									   NSArray.class,
									   NSDictionary.class,
									   ];
}
- (instancetype)init {
	if (self = [super init]) {
		fblm_original = @{};
		fblm_storage = [NSMutableDictionary dictionary];
	}
	return self;
}
- (instancetype)initWithJSONDictionary:(NSDictionary<NSString*, id>*)obj {
	if (!obj || ![obj isKindOfClass:[NSDictionary class]]) {
		NSLog(@"FBLM: parameter assert to initWithJSONDictionary on %@", [self class]);
		return nil;
	}

	if (self = [self init]) {
		fblm_original = obj;
	}
	return self;
}
+ (id)fblm_objectWithJSONFragment:(NSObject *)fragment {
	if ([fragment isKindOfClass:self]) {
		return fragment;
	} else if ([fragment isKindOfClass:[NSDictionary class]]) {
		return [[self alloc] initWithJSONDictionary:(NSDictionary*)fragment];
	} else if (!fragment) {
		return nil;
	}
	NSLog(@"FBLM: JSON Parse Error for extracting %@, with from JSON fragment: %@",self, fragment);
	return nil;
}

#pragma mark - Runtime Hooking!
+ (BOOL)resolveInstanceMethod:(SEL)sel {
	@synchronized (FBLiteModel.class) {
		if ([self fblm_resolveInstanceMethodSynchronized:sel]) {
			return YES;
		}
	}

	// Else:
	return [super resolveInstanceMethod:sel];
}
+ (BOOL)fblm_resolveInstanceMethodSynchronized:(SEL)sel {
	NSString * selName = NSStringFromSelector(sel);

	BOOL isSetter = [selName hasPrefix:@"set"];

	// 1. Collect Potential Classes to attach to
	for (Class theClass in [self fblm_targetClasses]) {
		BOOL bailLoops = NO;
		BOOL foundProperty = NO;

		BOOL dynamic = NO;
		BOOL isScalarType = NO;
		BOOL isObjectType = NO;
		BOOL expectsRetain = NO;

		NSString * propName = nil;
		char scalarType = '\0';
		Class objectType = Nil;

		BOOL atomicity = YES; // Default to atomic (because the ObjC runtime does)

		// 2. Find the specific class to work with by searching for dynamic properties
		unsigned int count = 0;
		objc_property_t * properties = class_copyPropertyList(theClass, &count);
		for (int i = 0; i < count && !foundProperty && !bailLoops; i++) {
			objc_property_t p = properties[i];
			// 3. Figure out if this property is eligible for dynamic instantiation

			const char * pName = property_getName(p);
			if (!pName) {continue;}
			propName = [NSString stringWithUTF8String:pName];
			if (![selName isEqualToString:propName]) {continue;}
			foundProperty = YES;

			unsigned int acount = 0;
			objc_property_attribute_t * attribs = property_copyAttributeList(p, &acount);
			for (int j = 0; j < acount && !bailLoops; j++) {
				objc_property_attribute_t attrib = attribs[j];

				// NSLog(@"\t\t\t%s: %s",attrib.name, attrib.value);
				const char attribStub = (!!attrib.name) ? attrib.name[0] : '\0';
				const char attribValStub = (!!attrib.value) ? attrib.value[0] : '\0';
				switch(attribStub) {
					case 'D':
						dynamic = YES;
						break;
					case 'T':
						if (attribValStub == '{') {
							NSLog(@"FBLM: Found property %@ matching selector: %@ on class %@. But requires a struct return of type %s, this is not yet supported, sorry!",propName,selName,theClass,attrib.value);
							bailLoops = true;
							break;
						}
						if (attribValStub == '@') {
							// Object Type!
							isObjectType = YES;
							NSString * cTypeName = [NSString stringWithCString:attrib.value encoding:NSUTF8StringEncoding];
							if (cTypeName.length == 1) {
								NSLog(@"FLLLM: Found property %@ matching selector: %@ on class %@. But type-encoding requires `id`, this is not yet supported, sorry!",propName,selName,theClass);
								bailLoops = true;
								break;
							}

							objectType = [self fblm_parseClassFromTypeEncoding:cTypeName];
							if (!objectType) {
								bailLoops = true;
							}
							break;
						}

						isScalarType = YES;
						scalarType = attribValStub;
						break;
					case '&':
						expectsRetain = YES;
						break;
					case 'N':
						atomicity = NO;
						break;
					case 'W':
						NSLog(@"FBLM: Found property %@ matching selector: %@ on class %@. But weak properties are not supported, sorry!",propName,selName,theClass);
						bailLoops = YES;
						break;
					case 'C':
						NSLog(@"FBLM: Found property %@ matching selector: %@ on class %@. But copy properties are not supported, sorry!",propName,selName,theClass);
						bailLoops = YES;
						break;
					case 'V':
						NSLog(@"FBLM: Found property %@ matching selector: %@ on class %@. Unfortunately, it's attached to an ivar already!",propName,selName,theClass);
						bailLoops = YES;
						break;
					default:
						break;
				}
			}
			free(attribs);
		}
		free(properties);

		if (bailLoops) {
			return NO;
		}

		if (!foundProperty) {
			// Continue looping!
			continue;
		}

		// 4. Validate the collected data from the runtime.
		if (isScalarType && isObjectType) {
			NSLog(@"FBLM: Found property %@ matching selector: %@ on class %@. ObjC Runtime claims this is both scalar & object. This shouldn't be possible. scalarType: %c objectType: %@",propName, selName, theClass,scalarType, objectType);
			return NO;
		}

		if (isScalarType) {

			// 5.a. Attach an IMP with the correct call signature!
		}
		if (isObjectType) {
			// Supported types are JSON compatible, *or* they are a subclass of FBLiteModel
			if (![objectType conformsToProtocol:@protocol(FBLiteModelConstruction)]) {
				NSLog(@"FBLM: Can't construct `%@` for property `%@` in `%@` because %@ does not conform to: FBLiteModelConstruction", objectType, propName, self, objectType);
				return NO;
			}
			if (![objectType conformsToProtocol:@protocol(FBLiteModelInstallObjectTypeProperty)]) {
				NSLog(@"FBLM: Can't construct `%@` for property `%@` in `%@` because %@ does not conform to: FBLiteModelInstallObjectTypeProperty", objectType, propName, self, objectType);
				return NO;
			}
			// 5.b. Attach an IMP with the correct call signature!
			if (!isSetter) {
				return [objectType fblm_installFBLMPropertyGetter:propName
														 selector:sel
														   atomic:atomicity
													   isNullable:NO
												   nullResettable:NO
														 forClass:self];
			} else {
				return [objectType fblm_installFBLMPropertySetter:propName
														 selector:sel
														   atomic:atomicity
													   isNullable:NO
												   nullResettable:NO
														 forClass:self];
			}
		}
	}
	return NO;
}

/// Get the relevant class hirearchy to work with!
+ (NSArray<Class>*)fblm_targetClasses {
	NSMutableArray<Class>* results = NSMutableArray.array;
	for (Class c = self; !!c && c != FBLiteModel.class; c = c.superclass) {
		[results addObject:c];
	}
	return results;
}
#pragma mark - Naming!
+ (NSString *)fblm_jsonKeyForGetterName:(NSString *)getterName {
	NSCharacterSet * upper = NSCharacterSet.uppercaseLetterCharacterSet;
	NSCharacterSet * underscore = [NSCharacterSet characterSetWithCharactersInString:@"_"];

	NSMutableString * result = NSMutableString.string;

	BOOL lastWasUpper = YES; // sequential uppercase letters aren't treated as a boundary
	BOOL lastWasUnderscore = NO; // Don't have multiple underscores (by convention

	// We know simple string iteration is safe because getters/setters can only have ascii symbols!
	for (NSUInteger idx = 0; idx < getterName.length; idx++) {
		unichar c = [getterName characterAtIndex:idx];

		BOOL isUnderscore = [underscore characterIsMember:c];
		BOOL isUpper = [upper characterIsMember:c];

		if (lastWasUnderscore && isUnderscore) {
			lastWasUpper = isUpper;
			continue;
		}
		if (isUpper && !(lastWasUnderscore || lastWasUpper)) {
			[result appendString:@"_"];
		}

		lastWasUnderscore = isUnderscore;
		lastWasUpper = isUpper;

		[result appendFormat:@"%c",c];
	}
	NSString * finalResult = result.lowercaseString;
	return finalResult;
}
+ (NSString *)fblm_jsonKeyForSetterName:(NSString *)setterName {
	if ([setterName hasPrefix:@"set"]) {
		return [self fblm_jsonKeyForGetterName:[setterName substringFromIndex:3]];
	}
//	if ([setterName hasPrefix:@"is"]) {
//		return [self fblm_jsonKeyForGetterName:[setterName substringFromIndex:2]];
//	}
	return [self fblm_jsonKeyForGetterName:setterName];
}
+ (nullable Class)fblm_parseClassFromTypeEncoding:(NSString*)tEncoding {
	if (!(tEncoding.length > 3 && [tEncoding hasPrefix:@"@\""] && [tEncoding hasSuffix:@"\""])) {
		NSLog(@"FLLLM: tried to parse an invalidly formatted type-encoding `%@` into a classname.", tEncoding);
		return Nil;
	}
	NSString * cName = [tEncoding substringWithRange:NSMakeRange(2, tEncoding.length - 3)];
	Class c = NSClassFromString(cName);
	if (!c) {
		NSLog(@"FLLLM: couldn't find a class named in type-encoding `%@` parsed into class-name `%@",tEncoding,cName);
	}
	return c;
}
@end

#define FBLM_INSTALL_OBJECT_PROPERTY(OBJTYPE) \
@implementation OBJTYPE (FBLiteModelInstallObjectTypeProperty)\
+ (BOOL)fblm_installFBLMPropertyGetter:(NSString*)propName\
							  selector:(SEL)sel\
								atomic:(BOOL)atomic\
							isNullable:(BOOL)isNullable\
						nullResettable:(BOOL)nullResettable\
							  forClass:(Class)targetClass {\
	NSString * jsonKey = [FBLiteModel fblm_jsonKeyForGetterName:propName];\
\
	if (!isNullable && ![OBJTYPE respondsToSelector:@selector(fblm_nonnullPropertyNilReplacement)]) {\
		NSLog(@"FBLM: tried to install a property getter `%@` on `%@` marked as nonnull, but the class did not define fblm_nonnullPropertyNilReplacement.", propName, targetClass);\
		return NO;\
	}\
\
	if (!atomic) {\
		static dispatch_once_t onceToken;\
		dispatch_once(&onceToken, ^{\
			NSLog(@"FBLM: all FBLiteModel properties are atomic. Sorry! `%@.%@` [will log once per property type]",targetClass,propName);\
		});\
	}\
\
\
	IMP imp = imp_implementationWithBlock(^OBJTYPE* (id self){\
		FBLiteModel * obj = self;\
\
		@synchronized (obj.fblm_storage) {\
			OBJTYPE * result = obj.fblm_storage[jsonKey];\
			if (!result) {\
				id tmp = obj.fblm_original[jsonKey];\
				if (!!tmp) {\
					result = [OBJTYPE fblm_objectWithJSONFragment: tmp];\
					if (result) {\
						// Write back to storage, after which point will always have either a value or our nil-placeholder (default NSNull).\
						obj.fblm_storage[jsonKey] = result;\
					}\
				}\
			} else if ((id)result == FBLiteModelNilReplacement) {\
				result = nil;\
			}\
\
			if (!result && !isNullable) {\
				result = [OBJTYPE fblm_nonnullPropertyNilReplacement];\
			}\
			return result;\
		}\
	});\
\
	NSString * canonicalString = [NSString stringWithFormat:@"fblm_canonicalTypeEncodingForGetter%@", [OBJTYPE class]];\
	SEL canonical = NSSelectorFromString(canonicalString);\
	const char * encoding = method_getTypeEncoding(class_getInstanceMethod(FBLiteModel.class, canonical));\
\
	BOOL ok = class_addMethod(targetClass,\
							  sel,\
							  imp,\
							  encoding);\
	return ok;\
}\
@end
//FBLM_INSTALL_OBJECT_PROPERTY(FBLiteModel)
//FBLM_INSTALL_OBJECT_PROPERTY(NSNumber)
//FBLM_INSTALL_OBJECT_PROPERTY(NSString)
#undef FBLM_INSTALL_OBJECT_PROPERTY

#define OBJTYPE NSString
@implementation OBJTYPE (FBLiteModelInstallObjectTypeProperty)
+ (BOOL)fblm_installFBLMPropertyGetter:(NSString*)propName
							  selector:(SEL)sel
								atomic:(BOOL)atomic
							isNullable:(BOOL)isNullable
						nullResettable:(BOOL)nullResettable
							  forClass:(Class)targetClass {
	NSString * jsonKey = [FBLiteModel fblm_jsonKeyForGetterName:propName];

	if (!isNullable && ![OBJTYPE respondsToSelector:@selector(fblm_nonnullPropertyNilReplacement)]) {
		NSLog(@"FBLM: tried to install a property getter `%@` on `%@` marked as nonnull, but the class did not define fblm_nonnullPropertyNilReplacement.", propName, targetClass);
		return NO;
	}

	if (!atomic) {
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			NSLog(@"FBLM: all FBLiteModel getter properties are atomic. Sorry! `%@.%@` [will log once per property type]",targetClass,propName);
		});
	}


	IMP imp = imp_implementationWithBlock(^OBJTYPE* (id self){
		FBLiteModel * obj = self;

		@synchronized (obj.fblm_storage) {
			OBJTYPE * result = obj.fblm_storage[jsonKey];
			if (!result) {
				id tmp = obj.fblm_original[jsonKey];
				if (!!tmp) {
					result = [OBJTYPE fblm_objectWithJSONFragment: tmp];
					if (result) {
						// Write back to storage, after which point will always have either a value or our nil-placeholder (default NSNull).
						obj.fblm_storage[jsonKey] = result;
					}
				}
			} else if ((id)result == FBLiteModelNilReplacement) {
				result = nil;
			}

			if (!result && !isNullable) {
				result = [OBJTYPE fblm_nonnullPropertyNilReplacement];
			}
			return result;
		}
	});

	NSString * canonicalString = @"fblm_canonicalTypeEncodingForGetter";
	SEL canonical = NSSelectorFromString(canonicalString);
	const char * encoding = method_getTypeEncoding(class_getInstanceMethod(OBJTYPE.class, canonical));

	BOOL ok = class_addMethod(targetClass,
							  sel,
							  imp,
							  encoding);
	return ok;
}
+ (BOOL)fblm_installFBLMPropertySetter:(NSString*)propName
							  selector:(SEL)sel
								atomic:(BOOL)atomic
							isNullable:(BOOL)isNullable
						nullResettable:(BOOL)nullResettable
							  forClass:(Class)targetClass {
	NSString * jsonKey = [FBLiteModel fblm_jsonKeyForSetterName:propName];

	if (!isNullable && ![OBJTYPE respondsToSelector:@selector(fblm_nonnullPropertyNilReplacement)]) {
		NSLog(@"FBLM: tried to install a property getter `%@` on `%@` marked as nonnull, but the class did not define fblm_nonnullPropertyNilReplacement.", propName, targetClass);
		return NO;
	}

	if (!atomic) {
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			NSLog(@"FBLM: all FBLiteModel setter properties are atomic. Sorry! `%@.%@` [will log once per property type]",targetClass,propName);
		});
	}


	IMP imp = imp_implementationWithBlock(^void(id self, id arg){
		FBLiteModel * obj = self;

		if (!arg && !isNullable) {

		}

		@synchronized (obj.fblm_storage) {
			OBJTYPE * result = obj.fblm_storage[jsonKey];
			if (!result) {
				id tmp = obj.fblm_original[jsonKey];
				if (!!tmp) {
					result = [OBJTYPE fblm_objectWithJSONFragment: tmp];
					if (result) {
						// Write back to storage, after which point will always have either a value or our nil-placeholder (default NSNull).
						obj.fblm_storage[jsonKey] = result;
					}
				}
			} else if ((id)result == FBLiteModelNilReplacement) {
				result = nil;
			}

			if (!result && !isNullable) {
				result = [OBJTYPE fblm_nonnullPropertyNilReplacement];
			}
		}
	});

	NSString * canonicalString = @"fblm_canonicalTypeEncodingForSetter";
	SEL canonical = NSSelectorFromString(canonicalString);
	const char * encoding = method_getTypeEncoding(class_getInstanceMethod(OBJTYPE.class, canonical));

	BOOL ok = class_addMethod(targetClass,
							  sel,
							  imp,
							  encoding);
	return ok;
}
- (OBJTYPE*)fblm_canonicalTypeEncodingForGetter {
	return nil;
}
- (void)fblm_canonicalTypeEncodingForSetter:(OBJTYPE*)arg {
	return;
}
@end
#undef OBJTYPE

#pragma mark - Construction
#define FBLM_JSONISH_CONSTRUCTABLE(OBJTYPE) \
@implementation OBJTYPE (FBLiteModelConstruction) \
+ (id)fblm_objectWithJSONFragment:(NSObject*)fragment { \
	if (!fragment) {return nil;} \
\
	if ([fragment isKindOfClass:self]) {\
		return fragment;\
	}\
	NSLog(@"FLLLM: JSON decode error expected " # OBJTYPE " in JSON but found `%@`.",fragment.class);\
	return nil;\
}\
@end
FBLM_JSONISH_CONSTRUCTABLE(NSNumber)
FBLM_JSONISH_CONSTRUCTABLE(NSString)
#undef FBLM_JSONISH_CONSTRUCTABLE

#pragma mark - Nullability
@implementation NSNumber (FBLiteModelNullability)
+ (id)fblm_nonnullPropertyNilReplacement {
	return @0;
}
@end
@implementation NSString (FBLiteModelNullability)
+ (id)fblm_nonnullPropertyNilReplacement {
	return @"";
}
@end
@implementation NSArray (FBLiteModelNullability)
+ (id)fblm_nonnullPropertyNilReplacement {
	return @[];
}
@end
@implementation NSDictionary (FBLiteModelNullability)
+ (id)fblm_nonnullPropertyNilReplacement {
	return @{};
}
@end
