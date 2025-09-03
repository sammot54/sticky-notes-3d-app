import SwiftUI

@main
struct StickyNotesOrganizerApp: App {
    @StateObject private var noteManager = NoteManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(noteManager)
        }
    }
}