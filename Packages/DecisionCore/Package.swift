// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DecisionCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DecisionCore", targets: ["DecisionCore"])],
    targets: [
        .target(name: "DecisionCore"),
        .testTarget(name: "DecisionCoreTests", dependencies: ["DecisionCore"],
                    resources: [.copy("Fixtures")])
    ]
)
