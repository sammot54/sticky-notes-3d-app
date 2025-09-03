import Foundation
import NaturalLanguage

class SmartActionDetector: ObservableObject {
    
    // MARK: - Detection Patterns
    
    private struct DetectionPattern {
        let regex: NSRegularExpression
        let actionType: ActionType
        let confidence: Float
        
        init(pattern: String, actionType: ActionType, confidence: Float = 1.0) {
            do {
                self.regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                self.actionType = actionType
                self.confidence = confidence
            } catch {
                // Fallback to simple pattern if regex fails
                self.regex = try! NSRegularExpression(pattern: "\\b\\w+\\b", options: [])
                self.actionType = actionType
                self.confidence = 0.1
            }
        }
    }
    
    private lazy var patterns: [DetectionPattern] = [
        // Email patterns
        DetectionPattern(
            pattern: "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b",
            actionType: .email,
            confidence: 0.95
        ),
        
        // Phone patterns
        DetectionPattern(
            pattern: "\\b(?:\\+?1[-.]?)?\\(?([0-9]{3})\\)?[-.]?([0-9]{3})[-.]?([0-9]{4})\\b",
            actionType: .phone,
            confidence: 0.9
        ),
        DetectionPattern(
            pattern: "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b",
            actionType: .phone,
            confidence: 0.85
        ),
        
        // URL patterns
        DetectionPattern(
            pattern: "https?://[\\w\\-_]+(\\.[\\w\\-_]+)+([\\w\\-\\.,@?^=%&:/~\\+#]*[\\w\\-\\@?^=%&/~\\+#])?",
            actionType: .url,
            confidence: 0.95
        ),
        DetectionPattern(
            pattern: "www\\.[\\w\\-_]+(\\.[\\w\\-_]+)+([\\w\\-\\.,@?^=%&:/~\\+#]*[\\w\\-\\@?^=%&/~\\+#])?",
            actionType: .url,
            confidence: 0.9
        ),
        
        // Date patterns
        DetectionPattern(
            pattern: "\\b(?:0?[1-9]|1[0-2])[-/.](?:0?[1-9]|[12][0-9]|3[01])[-/.](?:19|20)?\\d{2}\\b",
            actionType: .date,
            confidence: 0.8
        ),
        DetectionPattern(
            pattern: "\\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2},?\\s+\\d{4}\\b",
            actionType: .date,
            confidence: 0.85
        ),
        DetectionPattern(
            pattern: "\\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+\\d{1,2},?\\s+\\d{4}\\b",
            actionType: .date,
            confidence: 0.8
        ),
        
        // Address patterns
        DetectionPattern(
            pattern: "\\d+\\s+[A-Za-z\\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Place|Pl)\\b",
            actionType: .address,
            confidence: 0.75
        ),
        
        // Calendar event patterns
        DetectionPattern(
            pattern: "\\b(?:meeting|appointment|event|conference|call|interview|lunch|dinner|party)\\b.*(?:at|on|@)\\s*\\d{1,2}[:.]\\d{2}(?:\\s*(?:AM|PM|am|pm))?",
            actionType: .calendar,
            confidence: 0.7
        ),
        DetectionPattern(
            pattern: "\\b(?:schedule|plan|book|reserve)\\b.*(?:for|on)\\s*(?:today|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)",
            actionType: .calendar,
            confidence: 0.65
        ),
        
        // Contact patterns
        DetectionPattern(
            pattern: "\\b(?:call|contact|reach out to|get in touch with|email|text|message)\\s+([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)*)",
            actionType: .contact,
            confidence: 0.6
        ),
        
        // Task patterns
        DetectionPattern(
            pattern: "\\b(?:todo|to do|task|complete|finish|work on|handle|deal with|take care of)\\b",
            actionType: .task,
            confidence: 0.5
        ),
        DetectionPattern(
            pattern: "\\b(?:buy|purchase|get|pick up|order|grab)\\b",
            actionType: .task,
            confidence: 0.4
        )
    ]
    
    // MARK: - Context Keywords
    
    private let contextKeywords: [ActionType: [String]] = [
        .email: ["send", "reply", "forward", "compose", "email", "mail", "message"],
        .phone: ["call", "ring", "dial", "phone", "telephone", "mobile", "cell"],
        .calendar: ["schedule", "meeting", "appointment", "event", "reminder", "calendar", "plan"],
        .task: ["do", "complete", "finish", "handle", "work", "task", "todo", "action"],
        .contact: ["contact", "reach", "talk", "speak", "connect", "touch base"],
        .address: ["visit", "go to", "location", "address", "place", "venue"]
    ]
    
    // MARK: - Public Methods
    
    func detectActions(in text: String) -> [SmartAction] {
        var detectedActions: [SmartAction] = []
        let nsText = text as NSString
        
        // Run pattern matching
        for pattern in patterns {
            let matches = pattern.regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
            
            for match in matches {
                let matchedText = nsText.substring(with: match.range)
                let confidence = calculateConfidence(for: pattern.actionType, text: matchedText, context: text)
                
                // Only include high-confidence matches
                if confidence > 0.3 {
                    let action = SmartAction(
                        type: pattern.actionType,
                        value: matchedText.trimmingCharacters(in: .whitespacesAndNewlines),
                        confidence: confidence,
                        range: match.range
                    )
                    detectedActions.append(action)
                }
            }
        }
        
        // Detect actions using Natural Language processing
        let nlActions = detectActionsWithNL(in: text)
        detectedActions.append(contentsOf: nlActions)
        
        // Remove duplicates and sort by confidence
        detectedActions = removeDuplicates(from: detectedActions)
        detectedActions.sort { $0.confidence > $1.confidence }
        
        // Limit to top 10 actions to avoid noise
        return Array(detectedActions.prefix(10))
    }
    
    func extractEmails(from text: String) -> [String] {
        let emailPattern = "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b"
        return extractMatches(from: text, pattern: emailPattern)
    }
    
    func extractPhoneNumbers(from text: String) -> [String] {
        let phonePatterns = [
            "\\b(?:\\+?1[-.]?)?\\(?([0-9]{3})\\)?[-.]?([0-9]{3})[-.]?([0-9]{4})\\b",
            "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b"
        ]
        
        var phoneNumbers: [String] = []
        for pattern in phonePatterns {
            phoneNumbers.append(contentsOf: extractMatches(from: text, pattern: pattern))
        }
        
        return Array(Set(phoneNumbers)) // Remove duplicates
    }
    
    func extractURLs(from text: String) -> [String] {
        let urlPatterns = [
            "https?://[\\w\\-_]+(\\.[\\w\\-_]+)+([\\w\\-\\.,@?^=%&:/~\\+#]*[\\w\\-\\@?^=%&/~\\+#])?",
            "www\\.[\\w\\-_]+(\\.[\\w\\-_]+)+([\\w\\-\\.,@?^=%&:/~\\+#]*[\\w\\-\\@?^=%&/~\\+#])?"
        ]
        
        var urls: [String] = []
        for pattern in urlPatterns {
            urls.append(contentsOf: extractMatches(from: text, pattern: pattern))
        }
        
        return Array(Set(urls))
    }
    
    func extractDates(from text: String) -> [Date] {
        let dateStrings = extractMatches(from: text, pattern: "\\b(?:0?[1-9]|1[0-2])[-/.](?:0?[1-9]|[12][0-9]|3[01])[-/.](?:19|20)?\\d{2}\\b")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yyyy"
        
        var dates: [Date] = []
        for dateString in dateStrings {
            if let date = dateFormatter.date(from: dateString) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    func detectCalendarEvents(in text: String) -> [CalendarEvent] {
        var events: [CalendarEvent] = []
        
        // Look for time patterns
        let timePattern = "\\b(?:0?[0-9]|1[0-2])[:.]?[0-5][0-9]\\s*(?:AM|PM|am|pm)?\\b"
        let timeMatches = extractMatches(from: text, pattern: timePattern)
        
        // Look for event keywords
        let eventKeywords = ["meeting", "appointment", "call", "lunch", "dinner", "conference", "interview", "party", "event"]
        let lowercaseText = text.lowercased()
        
        for keyword in eventKeywords {
            if lowercaseText.contains(keyword) {
                // Extract context around the keyword
                let range = lowercaseText.range(of: keyword)
                if let range = range {
                    let contextStart = max(lowercaseText.startIndex, lowercaseText.index(range.lowerBound, offsetBy: -50, limitedBy: lowercaseText.startIndex) ?? range.lowerBound)
                    let contextEnd = min(lowercaseText.endIndex, lowercaseText.index(range.upperBound, offsetBy: 50, limitedBy: lowercaseText.endIndex) ?? range.upperBound)
                    let context = String(lowercaseText[contextStart..<contextEnd])
                    
                    let event = CalendarEvent(
                        title: keyword.capitalized,
                        context: context,
                        suggestedTime: timeMatches.first,
                        confidence: 0.6
                    )
                    events.append(event)
                }
            }
        }
        
        return events
    }
    
    func getPossibleActions(for actionType: ActionType) -> [String] {
        switch actionType {
        case .email:
            return ["Send Email", "Reply", "Forward", "Add to Contacts"]
        case .phone:
            return ["Call", "Add to Contacts", "Send Message"]
        case .url:
            return ["Open in Browser", "Share Link", "Save for Later"]
        case .date:
            return ["Create Calendar Event", "Set Reminder"]
        case .address:
            return ["Open in Maps", "Get Directions", "Share Location"]
        case .calendar:
            return ["Create Event", "Set Reminder", "Add to Calendar"]
        case .contact:
            return ["Call", "Send Email", "Add to Contacts"]
        case .task:
            return ["Add to Reminders", "Create Task", "Set Due Date"]
        }
    }
    
    // MARK: - Private Methods
    
    private func calculateConfidence(for actionType: ActionType, text: String, context: String) -> Float {
        var confidence: Float = 0.5 // Base confidence
        
        let lowercaseContext = context.lowercased()
        let lowercaseText = text.lowercased()
        
        // Boost confidence based on context keywords
        if let keywords = contextKeywords[actionType] {
            let keywordMatches = keywords.filter { lowercaseContext.contains($0) }.count
            confidence += Float(keywordMatches) * 0.1
        }
        
        // Adjust confidence based on action type specifics
        switch actionType {
        case .email:
            if text.contains("@") && text.contains(".") {
                confidence += 0.3
            }
            
        case .phone:
            if text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression).count >= 10 {
                confidence += 0.2
            }
            
        case .url:
            if text.hasPrefix("http") || text.hasPrefix("www") {
                confidence += 0.3
            }
            
        case .date:
            // Check if it's a valid date format
            let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            let matches = dateDetector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.count)) ?? []
            if !matches.isEmpty {
                confidence += 0.2
            }
            
        case .address:
            if lowercaseText.contains("street") || lowercaseText.contains("avenue") || lowercaseText.contains("road") {
                confidence += 0.2
            }
            
        case .calendar:
            if lowercaseContext.contains("schedule") || lowercaseContext.contains("time") {
                confidence += 0.1
            }
            
        case .contact:
            // Check if it looks like a proper name (capitalized words)
            let namePattern = "^[A-Z][a-z]+(?:\\s+[A-Z][a-z]+)*$"
            if text.range(of: namePattern, options: .regularExpression) != nil {
                confidence += 0.2
            }
            
        case .task:
            let taskIndicators = ["todo", "task", "complete", "finish", "buy", "get", "do"]
            if taskIndicators.contains(where: { lowercaseContext.contains($0) }) {
                confidence += 0.1
            }
        }
        
        return min(confidence, 1.0) // Cap at 1.0
    }
    
    private func detectActionsWithNL(in text: String) -> [SmartAction] {
        var actions: [SmartAction] = []
        
        // Use NLTagger to identify entities
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation]) { tag, tokenRange in
            
            if let tag = tag {
                let token = String(text[tokenRange])
                var actionType: ActionType?
                var confidence: Float = 0.5
                
                switch tag {
                case .personalName:
                    actionType = .contact
                    confidence = 0.6
                    
                case .placeName:
                    actionType = .address
                    confidence = 0.5
                    
                case .organizationName:
                    actionType = .contact
                    confidence = 0.4
                    
                default:
                    break
                }
                
                if let actionType = actionType {
                    let nsRange = NSRange(tokenRange, in: text)
                    let action = SmartAction(
                        type: actionType,
                        value: token,
                        confidence: confidence,
                        range: nsRange
                    )
                    actions.append(action)
                }
            }
            
            return true
        }
        
        // Detect additional patterns using linguistic analysis
        let languageRecognizer = NLLanguageRecognizer()
        languageRecognizer.processString(text)
        
        if let language = languageRecognizer.dominantLanguage {
            // Language-specific enhancements could go here
            if language == .english {
                actions.append(contentsOf: detectEnglishSpecificActions(in: text))
            }
        }
        
        return actions
    }
    
    private func detectEnglishSpecificActions(in text: String) -> [SmartAction] {
        var actions: [SmartAction] = []
        
        // Detect imperative sentences (likely tasks)
        let imperativePatterns = [
            "^(?:buy|get|pick up|purchase|order)\\s+(.+)",
            "^(?:call|contact|reach out to)\\s+(.+)",
            "^(?:email|send|write to)\\s+(.+)",
            "^(?:visit|go to|check out)\\s+(.+)",
            "^(?:remember to|don't forget to|need to)\\s+(.+)"
        ]
        
        for pattern in imperativePatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
            let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.count)) ?? []
            
            for match in matches {
                if match.numberOfRanges > 1 {
                    let nsText = text as NSString
                    let matchedText = nsText.substring(with: match.range(at: 1))
                    
                    let actionType: ActionType
                    if pattern.contains("buy|get|pick up|purchase|order") {
                        actionType = .task
                    } else if pattern.contains("call|contact") {
                        actionType = .contact
                    } else if pattern.contains("email|send|write") {
                        actionType = .email
                    } else if pattern.contains("visit|go to") {
                        actionType = .address
                    } else {
                        actionType = .task
                    }
                    
                    let action = SmartAction(
                        type: actionType,
                        value: matchedText.trimmingCharacters(in: .whitespacesAndNewlines),
                        confidence: 0.7,
                        range: match.range(at: 1)
                    )
                    actions.append(action)
                }
            }
        }
        
        return actions
    }
    
    private func extractMatches(from text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        
        return matches.map { nsText.substring(with: $0.range) }
    }
    
    private func removeDuplicates(from actions: [SmartAction]) -> [SmartAction] {
        var uniqueActions: [SmartAction] = []
        var seenValues: Set<String> = []
        
        for action in actions {
            let key = "\(action.type.rawValue):\(action.value.lowercased())"
            if !seenValues.contains(key) {
                seenValues.insert(key)
                uniqueActions.append(action)
            }
        }
        
        return uniqueActions
    }
}

// MARK: - Supporting Types

struct CalendarEvent {
    let title: String
    let context: String
    let suggestedTime: String?
    let confidence: Float
    
    var suggestedDate: Date? {
        guard let timeString = suggestedTime else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        if let time = formatter.date(from: timeString) {
            let calendar = Calendar.current
            let now = Date()
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            
            return calendar.date(bySettingHour: timeComponents.hour ?? 0,
                               minute: timeComponents.minute ?? 0,
                               second: 0,
                               of: now)
        }
        
        return nil
    }
}

// MARK: - Extensions

extension SmartActionDetector {
    
    /// Analyze text and provide structured insights
    func analyzeText(_ text: String) -> TextAnalysis {
        let actions = detectActions(in: text)
        let emails = extractEmails(from: text)
        let phones = extractPhoneNumbers(from: text)
        let urls = extractURLs(from: text)
        let dates = extractDates(from: text)
        let events = detectCalendarEvents(in: text)
        
        return TextAnalysis(
            originalText: text,
            detectedActions: actions,
            emails: emails,
            phoneNumbers: phones,
            urls: urls,
            dates: dates,
            calendarEvents: events
        )
    }
    
    /// Get action suggestions based on detected content
    func getActionSuggestions(for text: String) -> [ActionSuggestion] {
        let analysis = analyzeText(text)
        var suggestions: [ActionSuggestion] = []
        
        for action in analysis.detectedActions {
            let possibleActions = getPossibleActions(for: action.type)
            
            for possibleAction in possibleActions {
                let suggestion = ActionSuggestion(
                    title: possibleAction,
                    description: "Perform \(possibleAction.lowercased()) on '\(action.value)'",
                    actionType: action.type,
                    targetValue: action.value,
                    confidence: action.confidence
                )
                suggestions.append(suggestion)
            }
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
}

struct TextAnalysis {
    let originalText: String
    let detectedActions: [SmartAction]
    let emails: [String]
    let phoneNumbers: [String]
    let urls: [String]
    let dates: [Date]
    let calendarEvents: [CalendarEvent]
    
    var hasActions: Bool {
        return !detectedActions.isEmpty
    }
    
    var actionCount: Int {
        return detectedActions.count
    }
    
    var summary: String {
        var components: [String] = []
        
        if !emails.isEmpty {
            components.append("\(emails.count) email(s)")
        }
        if !phoneNumbers.isEmpty {
            components.append("\(phoneNumbers.count) phone number(s)")
        }
        if !urls.isEmpty {
            components.append("\(urls.count) URL(s)")
        }
        if !dates.isEmpty {
            components.append("\(dates.count) date(s)")
        }
        if !calendarEvents.isEmpty {
            components.append("\(calendarEvents.count) event(s)")
        }
        
        if components.isEmpty {
            return "No actionable items detected"
        } else {
            return "Detected: " + components.joined(separator: ", ")
        }
    }
}

struct ActionSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let actionType: ActionType
    let targetValue: String
    let confidence: Float
}