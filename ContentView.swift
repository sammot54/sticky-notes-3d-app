import SwiftUI
import VisionKit

struct ContentView: View {
    @EnvironmentObject private var noteManager: NoteManager
    @State private var showingAddNote = false
    @State private var showingSettings = false
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var selectedNote: StickyNote?
    @State private var is3DMode = false
    @State private var selectedImage: UIImage?
    @State private var view3DMode: View3DMode = .spatial
    @State private var showingSearch = false
    @State private var showingFilters = false
    @State private var showingScanDocument = false
    
    enum View3DMode: String, CaseIterable {
        case spatial = "Spatial"
        case clustered = "Clustered"
        case timeline = "Timeline"
        case mindPalace = "Mind Palace"
        
        var icon: String {
            switch self {
            case .spatial: return "cube"
            case .clustered: return "circles.hexagongrid"
            case .timeline: return "clock"
            case .mindPalace: return "brain.head.profile"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if is3DMode {
                    Advanced3DSceneView(
                        notes: noteManager.filteredNotes,
                        viewMode: view3DMode,
                        onNoteSelected: { note in
                            selectedNote = note
                        },
                        onNotePositionChanged: { note, position in
                            var updatedNote = note
                            updatedNote.updatePosition(position)
                            noteManager.updateNote(updatedNote)
                        }
                    )
                    .ignoresSafeArea()
                } else {
                    traditionalGridView
                }
                
                // Floating action buttons
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingActionMenu
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 30)
                }
                
                // Loading overlay
                if noteManager.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Processing...")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.top, 10)
                    }
                }
            }
            .navigationTitle(is3DMode ? "3D Notes" : "Sticky Notes")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if !is3DMode {
                        Button(action: { showingSearch.toggle() }) {
                            Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
                        }
                        
                        Button(action: { showingFilters.toggle() }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(hasActiveFilters ? .blue : .primary)
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if is3DMode {
                        Menu {
                            ForEach(View3DMode.allCases, id: \.self) { mode in
                                Button(action: { view3DMode = mode }) {
                                    Label(mode.rawValue, systemImage: mode.icon)
                                }
                            }
                        } label: {
                            Image(systemName: view3DMode.icon)
                        }
                    }
                    
                    Button(action: { is3DMode.toggle() }) {
                        Image(systemName: is3DMode ? "rectangle.grid.2x2" : "cube")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .searchable(
                text: $noteManager.searchText,
                isPresented: $showingSearch,
                prompt: "Search notes..."
            )
            .sheet(isPresented: $showingAddNote) {
                AddNoteView(selectedImage: selectedImage) { image in
                    selectedImage = image
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $selectedNote) { note in
                NoteDetailView(note: note)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage) { image in
                    selectedImage = image
                    showingAddNote = true
                }
            }
            .sheet(isPresented: $showingScanDocument) {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DocumentScannerView { image in
                        selectedImage = image
                        showingAddNote = true
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterView()
            }
            .alert("Error", isPresented: .constant(noteManager.error != nil)) {
                Button("OK") {
                    noteManager.error = nil
                }
            } message: {
                if let error = noteManager.error {
                    Text(error)
                }
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        noteManager.selectedCategory != nil || noteManager.selectedMood != nil
    }
    
    private var traditionalGridView: some View {
        ScrollView {
            LazyVGrid(columns: adaptiveColumns, spacing: 16) {
                ForEach(noteManager.filteredNotes) { note in
                    NoteCardView(note: note) {
                        selectedNote = note
                    }
                    .contextMenu {
                        contextMenu(for: note)
                    }
                }
            }
            .padding()
        }
        .refreshable {
            // Refresh logic if needed
        }
    }
    
    private var adaptiveColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)]
    }
    
    private var floatingActionMenu: some View {
        VStack(spacing: 12) {
            // Add note button
            Button(action: { showingAddNote = true }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            
            // Camera button
            Button(action: { showingImagePicker = true }) {
                Image(systemName: "camera")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.green)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            
            // Document scanner button
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                Button(action: { showingScanDocument = true }) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.orange)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
        }
    }
    
    @ViewBuilder
    private func contextMenu(for note: StickyNote) -> some View {
        Button(action: { selectedNote = note }) {
            Label("Edit", systemImage: "pencil")
        }
        
        Button(action: { noteManager.duplicateNote(note) }) {
            Label("Duplicate", systemImage: "doc.on.doc")
        }
        
        Button(action: { 
            if note.isArchived {
                noteManager.unarchiveNote(note)
            } else {
                noteManager.archiveNote(note)
            }
        }) {
            Label(note.isArchived ? "Unarchive" : "Archive", 
                  systemImage: note.isArchived ? "tray.and.arrow.up" : "tray.and.arrow.down")
        }
        
        Divider()
        
        Button(role: .destructive, action: { noteManager.deleteNote(note) }) {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Note Card View

struct NoteCardView: View {
    let note: StickyNote
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with category and mood
            HStack {
                Label(note.category.rawValue, systemImage: note.category.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(note.mood.emoji)
                    .font(.caption)
            }
            
            // Title
            if !note.title.isEmpty {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // Content preview
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.body)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
            }
            
            // Photo preview
            if let photo = note.photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 80)
                    .cornerRadius(8)
            }
            
            Spacer()
            
            // Footer with tags and actions
            VStack(alignment: .leading, spacing: 4) {
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(note.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                // Smart actions
                if !note.detectedActions.isEmpty {
                    HStack {
                        ForEach(note.detectedActions.prefix(3)) { action in
                            Image(systemName: action.type.icon)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        if note.detectedActions.count > 3 {
                            Text("+\(note.detectedActions.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Date
                Text(DateFormatter.localizedString(from: note.updatedAt, dateStyle: .none, timeStyle: .short))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(note.color.uiColor).opacity(0.3))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Filter View

struct FilterView: View {
    @EnvironmentObject private var noteManager: NoteManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category") {
                    Picker("Category", selection: $noteManager.selectedCategory) {
                        Text("All Categories").tag(Category?.none)
                        ForEach(Category.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(Category?.some(category))
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Section("Mood") {
                    Picker("Mood", selection: $noteManager.selectedMood) {
                        Text("All Moods").tag(Mood?.none)
                        ForEach(Mood.allCases, id: \.self) { mood in
                            HStack {
                                Text(mood.emoji)
                                Text(mood.rawValue)
                            }
                            .tag(Mood?.some(mood))
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Section("Quick Filters") {
                    NavigationLink("Notes with Photos") {
                        NotesListView(notes: noteManager.getNotesWithPhotos(), title: "Notes with Photos")
                    }
                    
                    NavigationLink("Notes with Actions") {
                        NotesListView(notes: noteManager.getNotesWithActions(), title: "Notes with Actions")
                    }
                    
                    NavigationLink("Recent Notes") {
                        NotesListView(notes: noteManager.getRecentNotes(), title: "Recent Notes")
                    }
                    
                    NavigationLink("Archived Notes") {
                        NotesListView(notes: noteManager.archivedNotes, title: "Archived Notes")
                    }
                }
                
                Section("Actions") {
                    Button("Clear All Filters") {
                        noteManager.selectedCategory = nil
                        noteManager.selectedMood = nil
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var noteManager: NoteManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var exportedText = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Statistics") {
                    HStack {
                        Text("Total Notes")
                        Spacer()
                        Text("\(noteManager.notes.filter { !$0.isArchived }.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Archived Notes")
                        Spacer()
                        Text("\(noteManager.archivedNotes.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Notes with Photos")
                        Spacer()
                        Text("\(noteManager.getNotesWithPhotos().count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Data Management") {
                    Button("Export All Notes") {
                        exportedText = noteManager.exportNotes()
                        showingExportSheet = true
                    }
                    
                    Button("Import Notes") {
                        showingImportSheet = true
                    }
                    
                    Button("Archive All Notes", role: .destructive) {
                        noteManager.archiveAllNotes()
                    }
                    
                    Button("Delete All Notes", role: .destructive) {
                        noteManager.deleteAllNotes()
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ShareSheet(activityItems: [exportedText])
            }
            .sheet(isPresented: $showingImportSheet) {
                // Import sheet implementation
                Text("Import functionality would go here")
            }
        }
    }
}

// MARK: - Notes List View

struct NotesListView: View {
    let notes: [StickyNote]
    let title: String
    @State private var selectedNote: StickyNote?
    
    var body: some View {
        List(notes) { note in
            VStack(alignment: .leading, spacing: 4) {
                if !note.title.isEmpty {
                    Text(note.title)
                        .font(.headline)
                }
                
                Text(note.content)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label(note.category.rawValue, systemImage: note.category.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(note.mood.emoji)
                        .font(.caption)
                    
                    Text(DateFormatter.localizedString(from: note.updatedAt, dateStyle: .short, timeStyle: .none))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 2)
            .onTapGesture {
                selectedNote = note
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedNote) { note in
            NoteDetailView(note: note)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
        .environmentObject(NoteManager())
}