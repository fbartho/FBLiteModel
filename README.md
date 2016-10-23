FBLiteModel
===========

## Purpose

Have you ever wanted a zero-config model-mapping layer where you're willing to sacrifice some performance for serious usability gains? FBLiteModel is your answer.

### Goals

- Fast/simple model creation without having to write parsing logic
- Robust behaviors even at the cost of performance.

### Limitations

- Does not have a serialization layer
- Model-mapped atomic fields are implemented by a single read/write lock on a backing NSMutableDictionary
- Only strong/assign properties will work as expected. `weak` & `copy` model-mapped fields are not supported, 
- Original values may be kept & duplicated as necessary.
- Be careful when using nullability annotations.
- Overriding a setter/getter won't work as expected, but you can custom implement your own
- Swift3.0 or greater!

### Features

- Non-model mapped fields & methods work as expected.
- Supported types: LiteModel-subclasses, NSString, NSNumber-compatible types.
- Extended features: NSArray/NSDictionary collections of the previous.
- Properties can be added from Categories!

## Implementation

When a property access faults, FLLiteModel generates an implementation at runtime. Because nullabilty requirements are a compile-time feature, your subclasses may need to hint how nullability should work. 

[Detailed Implementation Documentation](../blob/master/Implementation.md)

## Usage

[For initial setup, use Swift Package Manager](#installation)

To make a model, subclass FBLiteModel, and specify your @properties. Mark the properties as `@dynamic` and do not implement. 

### Examples

- objc.example
- swift.example

### Installation

To have one less thing to maintain, this project does not include an Xcodeproj of its own. Rather, it uses [Swift Package Manager](https://swift.org/package-manager), which comes included as of Xcode 8.

To build:

	$ swift build

And the output should be something like:

	Compile FBLiteModel FBLiteModel.m
	Compile Swift Module 'swift_example' (# sources)
	Linking ./.build/debug/swift.example
	Linking FBLiteModel
	Compile objc.example main.m
	Linking objc.example

If you'd like to help develop FBLiteModel, you can ask SwiftPM to generate an Xcodeproj.

	$ swift package generate-xcodeproj
	generated: ./FBLiteModel.xcodeproj

<sub>Note: as of 2016-10-22 SwiftPM does not include all the necessary headers for ObjC libraries when generating a project, so you need to edit the header search paths & drag in the headers folder. 
	`HEADER_SEARCH_PATHS = ${SOURCE_ROOT}/Sources/FBLiteModel/include`
</sub>

# License

- MIT

Please contact me if you'd like to discuss something else.
