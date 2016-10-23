import PackageDescription

let package = Package(
	name: "FBLiteModel",
	targets: [
		Target(name: "FBLiteModel"),
		Target(name: "swift.example", dependencies:["FBLiteModel"]),
		Target(name: "objc.example", dependencies:["FBLiteModel"]),
	]
)
