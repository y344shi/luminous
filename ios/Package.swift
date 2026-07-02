// swift-tools-version:6.0
//
// Test harness ONLY — the Xcode project never references this package.
// It compiles the pure, Foundation-only core files (the same sources the app
// target builds) into a `LuminousCore` module so `swift test` runs the fast
// green gate on the Mac host without touching Luminous.xcodeproj.
//
// When a new pure file is added to Luminous/, add one line to `sources:`.

import PackageDescription

let package = Package(
    name: "LuminousCore",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "LuminousCore",
            path: "Luminous",
            sources: [
                "Copy.swift",
                "Domain.swift",
                "Places.swift",
                "Recurrence.swift",
                "Rhythm.swift",
                "Scoring.swift",
                "SeedParser.swift",
                "SemanticTime.swift",
                "SensorClassifiers.swift",
                "Suggestion.swift",
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["LuminousCore"],
            path: "CoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
