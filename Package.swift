// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "Portal",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
  ],
  products: [
    .library(name: "Portal", targets: ["Portal"]),
    .library(name: "PortalNIO", targets: ["PortalNIO"]),
  ],
  dependencies: [
    .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
  ],
  targets: [
    .target(
      name: "Portal",
      dependencies: [],
      path: "Portal/"
    ),
    .target(
      name: "PortalNIO",
      dependencies: [
        "Portal",
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "NIOFoundationCompat", package: "swift-nio"),
      ],
      path: "PortalNIO/"
    ),
    .testTarget(
      name: "PortalTests",
      dependencies: ["Portal"]
    ),
  ]
)
