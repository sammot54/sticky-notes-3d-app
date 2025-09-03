import Foundation
import UIKit
import CoreLocation

struct StickyNote: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var category: Category
    var mood: Mood
    var createdAt: Date
    var updatedAt: Date
    var position: Position3D
    var color: NoteColor
    var priority: Priority
    var tags: [String]
    var photoData: Data?
    var detectedActions: [SmartAction]
    var size: NoteSize
    var isArchived: Bool
    var reminders: [NoteReminder]
    
    // Computed properties
    var hasPhoto: Bool {
        photoData != nil
    }
    
    var photo: UIImage? {
        guard let data = photoData else { return nil }
        return UIImage(data: data)
    }
    
    init(title: String = "", content: String = "", category: Category = .general, photo: UIImage? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.category = category
        self.mood = .neutral
        self.createdAt = Date()
        self.updatedAt = Date()
        self.position = Position3D.random()
        self.color = NoteColor.allCases.randomElement() ?? .yellow
        self.priority = .medium
        self.tags = []
        self.photoData = photo?.jpegData(compressionQuality: 0.8)
        self.detectedActions = []
        self.size = .medium
        self.isArchived = false
        self.reminders = []
    }
    
    mutating func updateContent(_ newContent: String) {
        self.content = newContent
        self.updatedAt = Date()
    }
    
    mutating func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
            updatedAt = Date()
        }
    }
    
    mutating func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        updatedAt = Date()
    }
    
    mutating func setPhoto(_ photo: UIImage?) {
        self.photoData = photo?.jpegData(compressionQuality: 0.8)
        self.updatedAt = Date()
    }
    
    mutating func addReminder(_ reminder: NoteReminder) {
        reminders.append(reminder)
        updatedAt = Date()
    }
    
    mutating func updatePosition(_ position: Position3D) {
        self.position = position
        self.updatedAt = Date()
    }
    
    static func == (lhs: StickyNote, rhs: StickyNote) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Supporting Types

struct Position3D: Codable {
    var x: Float
    var y: Float
    var z: Float
    
    init(x: Float = 0, y: Float = 0, z: Float = 0) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    static func random() -> Position3D {
        Position3D(
            x: Float.random(in: -10...10),
            y: Float.random(in: -5...5),
            z: Float.random(in: -10...10)
        )
    }
    
    func distance(to other: Position3D) -> Float {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
}

enum Category: String, CaseIterable, Codable {
    case general = "General"
    case work = "Work"
    case personal = "Personal"
    case ideas = "Ideas"
    case reminders = "Reminders"
    case shopping = "Shopping"
    case health = "Health"
    case travel = "Travel"
    case education = "Education"
    case finance = "Finance"
    
    var color: NoteColor {
        switch self {
        case .general: return .yellow
        case .work: return .blue
        case .personal: return .green
        case .ideas: return .purple
        case .reminders: return .orange
        case .shopping: return .pink
        case .health: return .red
        case .travel: return .cyan
        case .education: return .indigo
        case .finance: return .mint
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "note.text"
        case .work: return "briefcase"
        case .personal: return "person"
        case .ideas: return "lightbulb"
        case .reminders: return "bell"
        case .shopping: return "cart"
        case .health: return "heart"
        case .travel: return "airplane"
        case .education: return "book"
        case .finance: return "dollarsign.circle"
        }
    }
}

enum Mood: String, CaseIterable, Codable {
    case veryPositive = "Very Positive"
    case positive = "Positive"
    case neutral = "Neutral"
    case negative = "Negative"
    case veryNegative = "Very Negative"
    case excited = "Excited"
    case calm = "Calm"
    case urgent = "Urgent"
    case creative = "Creative"
    case analytical = "Analytical"
    
    var color: NoteColor {
        switch self {
        case .veryPositive: return .green
        case .positive: return .mint
        case .neutral: return .yellow
        case .negative: return .orange
        case .veryNegative: return .red
        case .excited: return .pink
        case .calm: return .blue
        case .urgent: return .red
        case .creative: return .purple
        case .analytical: return .indigo
        }
    }
    
    var emoji: String {
        switch self {
        case .veryPositive: return "😁"
        case .positive: return "😊"
        case .neutral: return "😐"
        case .negative: return "😞"
        case .veryNegative: return "😢"
        case .excited: return "🤩"
        case .calm: return "😌"
        case .urgent: return "⚡"
        case .creative: return "🎨"
        case .analytical: return "🧠"
        }
    }
}

enum NoteColor: String, CaseIterable, Codable {
    case yellow = "Yellow"
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case pink = "Pink"
    case purple = "Purple"
    case red = "Red"
    case cyan = "Cyan"
    case mint = "Mint"
    case indigo = "Indigo"
    
    var uiColor: UIColor {
        switch self {
        case .yellow: return .systemYellow
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .orange: return .systemOrange
        case .pink: return .systemPink
        case .purple: return .systemPurple
        case .red: return .systemRed
        case .cyan: return .systemCyan
        case .mint: return .systemMint
        case .indigo: return .systemIndigo
        }
    }
}

enum Priority: Int, CaseIterable, Codable {
    case low = 1
    case medium = 2
    case high = 3
    case urgent = 4
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var color: NoteColor {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

enum NoteSize: String, CaseIterable, Codable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    
    var scale: Float {
        switch self {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.2
        }
    }
}

struct SmartAction: Identifiable, Codable {
    let id: UUID
    let type: ActionType
    let value: String
    let confidence: Float
    let range: NSRange?
    
    init(type: ActionType, value: String, confidence: Float = 1.0, range: NSRange? = nil) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.confidence = confidence
        self.range = range
    }
}

enum ActionType: String, CaseIterable, Codable {
    case email = "Email"
    case phone = "Phone"
    case url = "URL"
    case date = "Date"
    case address = "Address"
    case calendar = "Calendar Event"
    case contact = "Contact"
    case task = "Task"
    
    var icon: String {
        switch self {
        case .email: return "envelope"
        case .phone: return "phone"
        case .url: return "link"
        case .date: return "calendar"
        case .address: return "location"
        case .calendar: return "calendar.badge.plus"
        case .contact: return "person.crop.circle.badge.plus"
        case .task: return "checkmark.circle"
        }
    }
}

struct NoteReminder: Identifiable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var isCompleted: Bool
    var notificationId: String?
    
    init(title: String, date: Date) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.isCompleted = false
        self.notificationId = nil
    }
}

// MARK: - Extensions

extension NSRange: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(location, forKey: .location)
        try container.encode(length, forKey: .length)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let location = try container.decode(Int.self, forKey: .location)
        let length = try container.decode(Int.self, forKey: .length)
        self.init(location: location, length: length)
    }
    
    enum CodingKeys: String, CodingKey {
        case location, length
    }
}