import Foundation
import SwiftUI
import Vision
import VisionKit
import NaturalLanguage
import UserNotifications
import CoreML

@MainActor
class NoteManager: ObservableObject {
    @Published var notes: [StickyNote] = []
    @Published var searchText: String = ""
    @Published var selectedCategory: Category? = nil
    @Published var selectedMood: Mood? = nil
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    private let smartActionDetector = SmartActionDetector()
    private let advanced3DEngine = Advanced3DNotesEngine()
    private let calendarIntegration = CalendarIntegration()
    
    // Filtering and search
    var filteredNotes: [StickyNote] {
        var filtered = notes.filter { !$0.isArchived }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        if let mood = selectedMood {
            filtered = filtered.filter { $0.mood == mood }
        }
        
        return filtered.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var archivedNotes: [StickyNote] {
        notes.filter { $0.isArchived }.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    init() {
        loadNotes()
        requestNotificationPermissions()
    }
    
    // MARK: - Note Management
    
    func addNote(_ note: StickyNote) {
        var processedNote = note
        
        // Process content with OCR if it has a photo
        if let photo = note.photo {
            processWithOCR(photo) { [weak self] ocrText in
                if let ocrText = ocrText, !ocrText.isEmpty {
                    processedNote.content += (processedNote.content.isEmpty ? "" : "\n\n") + ocrText
                }
                
                // Detect smart actions
                processedNote.detectedActions = self?.smartActionDetector.detectActions(in: processedNote.content) ?? []
                
                // Analyze mood and categorize
                self?.analyzeMoodAndCategory(for: &processedNote)
                
                // Generate 3D position using AI clustering
                processedNote.position = self?.advanced3DEngine.generateOptimalPosition(for: processedNote, in: self?.notes ?? []) ?? Position3D.random()
                
                DispatchQueue.main.async {
                    self?.notes.append(processedNote)
                    self?.saveNotes()
                }
            }
        } else {
            // Process text-only note
            processedNote.detectedActions = smartActionDetector.detectActions(in: processedNote.content)
            analyzeMoodAndCategory(for: &processedNote)
            processedNote.position = advanced3DEngine.generateOptimalPosition(for: processedNote, in: notes)
            
            notes.append(processedNote)
            saveNotes()
        }
    }
    
    func updateNote(_ note: StickyNote) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        
        var updatedNote = note
        updatedNote.updatedAt = Date()
        
        // Re-process smart actions if content changed
        if notes[index].content != note.content {
            updatedNote.detectedActions = smartActionDetector.detectActions(in: note.content)
            analyzeMoodAndCategory(for: &updatedNote)
        }
        
        notes[index] = updatedNote
        saveNotes()
    }
    
    func deleteNote(_ note: StickyNote) {
        notes.removeAll { $0.id == note.id }
        saveNotes()
    }
    
    func archiveNote(_ note: StickyNote) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index].isArchived = true
        notes[index].updatedAt = Date()
        saveNotes()
    }
    
    func unarchiveNote(_ note: StickyNote) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index].isArchived = false
        notes[index].updatedAt = Date()
        saveNotes()
    }
    
    func duplicateNote(_ note: StickyNote) {
        var duplicatedNote = note
        duplicatedNote.id = UUID()
        duplicatedNote.title += " (Copy)"
        duplicatedNote.createdAt = Date()
        duplicatedNote.updatedAt = Date()
        duplicatedNote.position = advanced3DEngine.generateOptimalPosition(for: duplicatedNote, in: notes)
        
        notes.append(duplicatedNote)
        saveNotes()
    }
    
    // MARK: - OCR Processing
    
    func processWithOCR(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        isLoading = true
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = "OCR Error: \(error.localizedDescription)"
                    completion(nil)
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                completion(recognizedText.isEmpty ? nil : recognizedText)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = "OCR Processing Error: \(error.localizedDescription)"
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - AI Analysis
    
    private func analyzeMoodAndCategory(for note: inout StickyNote) {
        let text = note.title + " " + note.content
        
        // Mood detection using Natural Language framework
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        if let sentimentScore = sentiment?.rawValue, let score = Double(sentimentScore) {
            switch score {
            case 0.5...1.0:
                note.mood = .veryPositive
            case 0.1..<0.5:
                note.mood = .positive
            case -0.1...0.1:
                note.mood = .neutral
            case -0.5..<(-0.1):
                note.mood = .negative
            case -1.0..<(-0.5):
                note.mood = .veryNegative
            default:
                note.mood = .neutral
            }
        }
        
        // Category detection based on keywords
        let lowercasedText = text.lowercased()
        
        let categoryKeywords: [Category: [String]] = [
            .work: ["meeting", "deadline", "project", "office", "boss", "colleague", "presentation", "report"],
            .personal: ["family", "friend", "home", "personal", "relationship", "birthday", "anniversary"],
            .ideas: ["idea", "brainstorm", "creative", "invention", "concept", "innovation", "think"],
            .reminders: ["remind", "remember", "don't forget", "todo", "task", "appointment"],
            .shopping: ["buy", "purchase", "shop", "store", "grocery", "mall", "online", "order"],
            .health: ["doctor", "medicine", "exercise", "diet", "hospital", "health", "workout", "medical"],
            .travel: ["travel", "trip", "vacation", "flight", "hotel", "destination", "passport", "luggage"],
            .education: ["study", "learn", "course", "school", "university", "exam", "homework", "lecture"],
            .finance: ["money", "budget", "bank", "investment", "savings", "expense", "financial", "payment"]
        ]
        
        var bestMatch: Category = .general
        var maxMatches = 0
        
        for (category, keywords) in categoryKeywords {
            let matches = keywords.filter { lowercasedText.contains($0) }.count
            if matches > maxMatches {
                maxMatches = matches
                bestMatch = category
            }
        }
        
        if maxMatches > 0 {
            note.category = bestMatch
        }
        
        // Detect urgency keywords
        let urgentKeywords = ["urgent", "asap", "emergency", "critical", "immediately", "deadline"]
        if urgentKeywords.contains(where: { lowercasedText.contains($0) }) {
            note.priority = .urgent
            note.mood = .urgent
        }
        
        // Detect creative keywords
        let creativeKeywords = ["create", "design", "art", "creative", "imagine", "innovate"]
        if creativeKeywords.contains(where: { lowercasedText.contains($0) }) {
            note.mood = .creative
        }
    }
    
    // MARK: - Smart Actions
    
    func executeSmartAction(_ action: SmartAction) {
        switch action.type {
        case .email:
            openEmail(action.value)
        case .phone:
            callPhone(action.value)
        case .url:
            openURL(action.value)
        case .calendar:
            calendarIntegration.createEvent(from: action.value)
        case .address:
            openMaps(action.value)
        case .contact:
            openContacts(action.value)
        case .task:
            // Handle task action
            break
        case .date:
            // Handle date action
            break
        }
    }
    
    private func openEmail(_ email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func callPhone(_ phone: String) {
        if let url = URL(string: "tel:\(phone)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openMaps(_ address: String) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?q=\(encodedAddress)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openContacts(_ contact: String) {
        // Implementation for opening contacts
    }
    
    // MARK: - Persistence
    
    private func saveNotes() {
        do {
            let data = try JSONEncoder().encode(notes)
            UserDefaults.standard.set(data, forKey: "sticky_notes")
        } catch {
            self.error = "Failed to save notes: \(error.localizedDescription)"
        }
    }
    
    private func loadNotes() {
        guard let data = UserDefaults.standard.data(forKey: "sticky_notes") else { return }
        
        do {
            notes = try JSONDecoder().decode([StickyNote].self, from: data)
        } catch {
            self.error = "Failed to load notes: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.error = "Notification permission error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func scheduleReminder(for note: StickyNote, at date: Date, title: String) {
        let content = UNMutableNotificationContent()
        content.title = "Note Reminder"
        content.body = title
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "note_\(note.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.error = "Failed to schedule reminder: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    
    func deleteAllNotes() {
        notes.removeAll()
        saveNotes()
    }
    
    func archiveAllNotes() {
        for i in notes.indices {
            notes[i].isArchived = true
            notes[i].updatedAt = Date()
        }
        saveNotes()
    }
    
    func exportNotes() -> String {
        let exportText = notes.map { note in
            """
            Title: \(note.title)
            Category: \(note.category.rawValue)
            Created: \(DateFormatter.localizedString(from: note.createdAt, dateStyle: .short, timeStyle: .short))
            Content:
            \(note.content)
            
            ---
            
            """
        }.joined()
        
        return exportText
    }
    
    func importNotes(from text: String) {
        // Simple import implementation - could be enhanced
        let sections = text.components(separatedBy: "---")
        
        for section in sections {
            let lines = section.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard lines.count > 3 else { continue }
            
            let title = String(lines[0].dropFirst(7)) // Remove "Title: "
            let categoryString = String(lines[1].dropFirst(10)) // Remove "Category: "
            let category = Category(rawValue: categoryString) ?? .general
            
            let contentStartIndex = lines.firstIndex { $0.starts(with: "Content:") } ?? 3
            let content = lines.dropFirst(contentStartIndex + 1).joined(separator: "\n")
            
            let note = StickyNote(title: title, content: content, category: category)
            addNote(note)
        }
    }
}

// MARK: - Extensions

extension NoteManager {
    func getNotesByCategory(_ category: Category) -> [StickyNote] {
        filteredNotes.filter { $0.category == category }
    }
    
    func getNotesByMood(_ mood: Mood) -> [StickyNote] {
        filteredNotes.filter { $0.mood == mood }
    }
    
    func getNotesByPriority(_ priority: Priority) -> [StickyNote] {
        filteredNotes.filter { $0.priority == priority }
    }
    
    func getNotesWithActions() -> [StickyNote] {
        filteredNotes.filter { !$0.detectedActions.isEmpty }
    }
    
    func getNotesWithPhotos() -> [StickyNote] {
        filteredNotes.filter { $0.hasPhoto }
    }
    
    func getRecentNotes(days: Int = 7) -> [StickyNote] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return filteredNotes.filter { $0.createdAt >= cutoffDate }
    }
}