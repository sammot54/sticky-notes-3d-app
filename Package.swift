// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "StickyNotes3D",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .executable(
            name: "StickyNotes3D",
            targets: ["StickyNotes3D"]
        )
    ],
    dependencies: [
        // No external dependencies required - using only iOS frameworks
    ],
    targets: [
        .executableTarget(
            name: "StickyNotes3D",
            dependencies: [],
            path: ".",
            sources: [
                "StickyNotesOrganizerApp.swift",
                "ContentView.swift",
                "StickyNote.swift",
                "NoteManager.swift",
                "Advanced3DNotesEngine.swift",
                "Advanced3DSceneView.swift",
                "SmartActionDetector.swift",
                "CalendarIntegration.swift",
                "ImagePicker.swift",
                "UIComponents.swift"
            ]
        )
    ]
)