import SwiftUI
import VisionKit

struct AddNoteView: View {
    @EnvironmentObject private var noteManager: NoteManager
    @Environment(\.dismiss) private var dismiss
    
    let selectedImage: UIImage?
    let onImageSelected: (UIImage?) -> Void
    
    @State private var title = ""
    @State private var content = ""
    @State private var selectedCategory = Category.general
    @State private var selectedColor = NoteColor.yellow
    @State private var selectedPriority = Priority.medium
    @State private var tags = ""
    @State private var currentImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingImageEditor = false
    @State private var showingCameraPicker = false
    @State private var showingDocumentScanner = false
    @State private var reminderDate = Date().addingTimeInterval(3600)
    @State private var hasReminder = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $content)
                            .frame(minHeight: 100)
                        
                        if content.isEmpty {
                            Text("Write your note here...")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                        }
                    }
                }
                
                Section("Categorization") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(Category.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Color", selection: $selectedColor) {
                        ForEach(NoteColor.allCases, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(Color(color.uiColor))
                                    .frame(width: 20, height: 20)
                                Text(color.rawValue)
                            }
                            .tag(color)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(Color(priority.color.uiColor))
                                    .frame(width: 12, height: 12)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Tags") {
                    TextField("Tags (comma separated)", text: $tags)
                        .textFieldStyle(.roundedBorder)
                    
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(tagArray, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Section("Photo") {
                    if let image = currentImage {
                        VStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                            
                            HStack {
                                Button("Edit") {
                                    showingImageEditor = true
                                }
                                .foregroundColor(.blue)
                                
                                Spacer()
                                
                                Button("Remove", role: .destructive) {
                                    currentImage = nil
                                    onImageSelected(nil)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Button(action: { showingCameraPicker = true }) {
                                Label("Take Photo", systemImage: "camera")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: { showingImagePicker = true }) {
                                Label("Choose from Library", systemImage: "photo")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                                Button(action: { showingDocumentScanner = true }) {
                                    Label("Scan Document", systemImage: "doc.text.viewfinder")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                
                Section("Reminder") {
                    Toggle("Set Reminder", isOn: $hasReminder)
                    
                    if hasReminder {
                        DatePicker("Reminder Time", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                if !content.isEmpty {
                    Section("Smart Actions") {
                        let smartActions = SmartActionDetector().detectActions(in: content)
                        
                        if smartActions.isEmpty {
                            Text("No actions detected")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(smartActions) { action in
                                HStack {
                                    Image(systemName: action.type.icon)
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading) {
                                        Text(action.type.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(action.value)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(Int(action.confidence * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(title.isEmpty && content.isEmpty)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $currentImage) { image in
                    currentImage = image
                    onImageSelected(image)
                }
            }
            .sheet(isPresented: $showingCameraPicker) {
                CameraPicker(selectedImage: $currentImage) { image in
                    currentImage = image
                    onImageSelected(image)
                }
            }
            .sheet(isPresented: $showingDocumentScanner) {
                DocumentScannerView { image in
                    currentImage = image
                    onImageSelected(image)
                }
            }
            .sheet(isPresented: $showingImageEditor) {
                ImageEditorView(image: $currentImage)
            }
        }
        .onAppear {
            currentImage = selectedImage
        }
    }
    
    private var tagArray: [String] {
        tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func saveNote() {
        var note = StickyNote(
            title: title,
            content: content,
            category: selectedCategory,
            photo: currentImage
        )
        
        note.color = selectedColor
        note.priority = selectedPriority
        note.tags = tagArray
        
        noteManager.addNote(note)
        
        if hasReminder {
            noteManager.scheduleReminder(for: note, at: reminderDate, title: title.isEmpty ? "Note Reminder" : title)
        }
        
        dismiss()
    }
}

struct NoteDetailView: View {
    @EnvironmentObject private var noteManager: NoteManager
    @Environment(\.dismiss) private var dismiss
    
    let note: StickyNote
    @State private var editedNote: StickyNote
    @State private var isEditing = false
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var showingDeleteAlert = false
    
    init(note: StickyNote) {
        self.note = note
        self._editedNote = State(initialValue: note)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with category and mood
                    HStack {
                        Label(editedNote.category.rawValue, systemImage: editedNote.category.icon)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack {
                            Text(editedNote.mood.emoji)
                            Text(editedNote.mood.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Circle()
                            .fill(Color(editedNote.priority.color.uiColor))
                            .frame(width: 12, height: 12)
                    }
                    .padding()
                    .background(Color(editedNote.color.uiColor).opacity(0.2))
                    .cornerRadius(12)
                    
                    // Title
                    if isEditing {
                        TextField("Title", text: $editedNote.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .textFieldStyle(.roundedBorder)
                    } else if !editedNote.title.isEmpty {
                        Text(editedNote.title)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    // Content
                    if isEditing {
                        TextEditor(text: $editedNote.content)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    } else {
                        Text(editedNote.content)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    
                    // Photo
                    if let photo = editedNote.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    }
                    
                    // Tags
                    if !editedNote.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.headline)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                ForEach(editedNote.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    // Smart Actions
                    if !editedNote.detectedActions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Detected Actions")
                                .font(.headline)
                            
                            ForEach(editedNote.detectedActions) { action in
                                ActionRow(action: action) {
                                    noteManager.executeSmartAction(action)
                                }
                            }
                        }
                    }
                    
                    // Reminders
                    if !editedNote.reminders.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reminders")
                                .font(.headline)
                            
                            ForEach(editedNote.reminders) { reminder in
                                ReminderRow(reminder: reminder)
                            }
                        }
                    }
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Created:")
                            Spacer()
                            Text(DateFormatter.localizedString(from: editedNote.createdAt, dateStyle: .medium, timeStyle: .short))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Updated:")
                            Spacer()
                            Text(DateFormatter.localizedString(from: editedNote.updatedAt, dateStyle: .medium, timeStyle: .short))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Note Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isEditing {
                            Button("Save") {
                                noteManager.updateNote(editedNote)
                                isEditing = false
                            }
                        } else {
                            Button("Edit") {
                                isEditing = true
                            }
                        }
                        
                        Button(action: { showingActionSheet = true }) {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(
                    title: Text("Note Actions"),
                    buttons: [
                        .default(Text("Duplicate")) {
                            noteManager.duplicateNote(editedNote)
                        },
                        .default(Text(editedNote.isArchived ? "Unarchive" : "Archive")) {
                            if editedNote.isArchived {
                                noteManager.unarchiveNote(editedNote)
                            } else {
                                noteManager.archiveNote(editedNote)
                            }
                        },
                        .destructive(Text("Delete")) {
                            showingDeleteAlert = true
                        },
                        .cancel()
                    ]
                )
            }
            .alert("Delete Note", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    noteManager.deleteNote(editedNote)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this note? This action cannot be undone.")
            }
        }
    }
}

struct ActionRow: View {
    let action: SmartAction
    let onExecute: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: action.type.icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(action.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(action.value)
                    .font(.body)
            }
            
            Spacer()
            
            VStack {
                Text("\(Int(action.confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Button("Execute") {
                    onExecute()
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ReminderRow: View {
    let reminder: NoteReminder
    
    var body: some View {
        HStack {
            Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "clock")
                .foregroundColor(reminder.isCompleted ? .green : .blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.body)
                    .strikethrough(reminder.isCompleted)
                
                Text(DateFormatter.localizedString(from: reminder.date, dateStyle: .medium, timeStyle: .short))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !reminder.isCompleted && reminder.date < Date() {
                Text("Overdue")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct DocumentScannerView: UIViewControllerRepresentable {
    let onDocumentScanned: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        
        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 {
                let scannedImage = scan.imageOfPage(at: 0)
                parent.onDocumentScanned(scannedImage)
            }
            parent.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }
    }
}

#Preview {
    let sampleNote = StickyNote(
        title: "Sample Note",
        content: "This is a sample note with some content to show in the detail view. It includes various features like tags, smart actions, and more.",
        category: .work
    )
    
    return NoteDetailView(note: sampleNote)
        .environmentObject(NoteManager())
}