import Foundation
import EventKit
import UserNotifications

class CalendarIntegration: ObservableObject {
    
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isAuthorized = false
    @Published var error: String?
    
    init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        if #available(iOS 17.0, *) {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        } else {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
        isAuthorized = authorizationStatus == .fullAccess || authorizationStatus == .authorized
    }
    
    func requestAccess() async {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    self.authorizationStatus = granted ? .fullAccess : .denied
                }
            } else {
                // For iOS 16 and below
                let granted = try await eventStore.requestAccess(to: .event)
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    self.authorizationStatus = granted ? .authorized : .denied
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to request calendar access: \(error.localizedDescription)"
                self.isAuthorized = false
            }
        }
    }
    
    // MARK: - Event Creation
    
    func createEvent(from text: String, title: String = "", startDate: Date = Date(), duration: TimeInterval = 3600) async -> Bool {
        guard isAuthorized else {
            await requestAccess()
            guard isAuthorized else {
                error = "Calendar access not granted"
                return false
            }
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title.isEmpty ? extractEventTitle(from: text) : title
        event.notes = text
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Try to extract more details from text
        let eventDetails = parseEventDetails(from: text)
        if let location = eventDetails.location {
            event.location = location
        }
        
        if let extractedDate = eventDetails.date {
            event.startDate = extractedDate
            event.endDate = extractedDate.addingTimeInterval(duration)
        }
        
        // Set alarm based on priority keywords
        if text.lowercased().contains("urgent") || text.lowercased().contains("important") {
            let alarm = EKAlarm(relativeOffset: -900) // 15 minutes before
            event.addAlarm(alarm)
        } else {
            let alarm = EKAlarm(relativeOffset: -3600) // 1 hour before
            event.addAlarm(alarm)
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to create event: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func createEventFromAction(_ action: SmartAction) async -> Bool {
        let title = generateEventTitle(from: action)
        let suggestedDate = extractDateFromAction(action) ?? Date().addingTimeInterval(3600) // Default to 1 hour from now
        
        return await createEvent(from: action.value, title: title, startDate: suggestedDate)
    }
    
    func createQuickEvent(title: String, date: Date, duration: TimeInterval = 3600, location: String? = nil) async -> Bool {
        guard isAuthorized else {
            await requestAccess()
            guard isAuthorized else {
                error = "Calendar access not granted"
                return false
            }
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = date
        event.endDate = date.addingTimeInterval(duration)
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        if let location = location {
            event.location = location
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to create quick event: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Event Retrieval
    
    func getUpcomingEvents(from startDate: Date = Date(), days: Int = 30) -> [EKEvent] {
        guard isAuthorized else { return [] }
        
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        
        return eventStore.events(matching: predicate)
    }
    
    func findSimilarEvents(to note: StickyNote) -> [EKEvent] {
        let events = getUpcomingEvents()
        let noteText = (note.title + " " + note.content).lowercased()
        
        return events.filter { event in
            let eventText = ((event.title ?? "") + " " + (event.notes ?? "")).lowercased()
            return hasCommonWords(noteText, eventText, minimumCommon: 2)
        }
    }
    
    // MARK: - Event Suggestions
    
    func suggestEventsFromNote(_ note: StickyNote) -> [EventSuggestion] {
        var suggestions: [EventSuggestion] = []
        let text = note.title + " " + note.content
        
        // Look for time indicators
        let timePatterns = [
            "(?:at|@)\\s*(\\d{1,2}[:.]\\d{2}\\s*(?:AM|PM|am|pm)?)",
            "(?:on|for)\\s*((?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|today|tomorrow))",
            "(?:next|this)\\s*(week|month|monday|tuesday|wednesday|thursday|friday|saturday|sunday)"
        ]
        
        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
                
                for match in matches {
                    if match.numberOfRanges > 1 {
                        let nsText = text as NSString
                        let timeString = nsText.substring(with: match.range(at: 1))
                        
                        if let suggestedDate = parseTimeString(timeString) {
                            let suggestion = EventSuggestion(
                                title: extractEventTitle(from: text),
                                date: suggestedDate,
                                description: text,
                                confidence: 0.8,
                                source: .timePattern
                            )
                            suggestions.append(suggestion)
                        }
                    }
                }
            }
        }
        
        // Look for meeting keywords
        let meetingKeywords = ["meeting", "call", "conference", "appointment", "interview", "lunch", "dinner"]
        let lowercaseText = text.lowercased()
        
        for keyword in meetingKeywords {
            if lowercaseText.contains(keyword) {
                let suggestion = EventSuggestion(
                    title: keyword.capitalized + " - " + note.title,
                    date: Date().addingTimeInterval(24 * 60 * 60), // Tomorrow
                    description: text,
                    confidence: 0.6,
                    source: .keywordMatch
                )
                suggestions.append(suggestion)
            }
        }
        
        // Look for deadline keywords
        let deadlineKeywords = ["deadline", "due", "submit", "complete by"]
        
        for keyword in deadlineKeywords {
            if lowercaseText.contains(keyword) {
                let suggestion = EventSuggestion(
                    title: "Deadline: " + note.title,
                    date: Date().addingTimeInterval(7 * 24 * 60 * 60), // Next week
                    description: text,
                    confidence: 0.7,
                    source: .deadlineDetection
                )
                suggestions.append(suggestion)
            }
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    func createEventFromSuggestion(_ suggestion: EventSuggestion) async -> Bool {
        return await createEvent(
            from: suggestion.description,
            title: suggestion.title,
            startDate: suggestion.date
        )
    }
    
    // MARK: - Reminder Integration
    
    func scheduleReminderForNote(_ note: StickyNote, at date: Date) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = "Note Reminder"
        content.body = note.title.isEmpty ? String(note.content.prefix(100)) : note.title
        content.sound = .default
        content.categoryIdentifier = "NOTE_REMINDER"
        
        // Add custom action buttons
        let openAction = UNNotificationAction(identifier: "OPEN_NOTE", title: "Open Note", options: [.foreground])
        let completeAction = UNNotificationAction(identifier: "COMPLETE_TASK", title: "Mark Complete", options: [])
        let snoozeAction = UNNotificationAction(identifier: "SNOOZE_REMINDER", title: "Snooze", options: [])
        
        let category = UNNotificationCategory(
            identifier: "NOTE_REMINDER",
            actions: [openAction, completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "note_reminder_\(note.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to schedule reminder: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Calendar Analysis
    
    func analyzeCalendarPatterns() -> CalendarAnalysis {
        let events = getUpcomingEvents(days: 90) // Last 3 months
        
        var hourCounts: [Int: Int] = [:]
        var dayCounts: [Int: Int] = [:]
        var durationStats: [TimeInterval] = []
        
        for event in events {
            let hour = Calendar.current.component(.hour, from: event.startDate)
            let dayOfWeek = Calendar.current.component(.weekday, from: event.startDate)
            let duration = event.endDate.timeIntervalSince(event.startDate)
            
            hourCounts[hour, default: 0] += 1
            dayCounts[dayOfWeek, default: 0] += 1
            durationStats.append(duration)
        }
        
        let preferredHour = hourCounts.max(by: { $0.value < $1.value })?.key ?? 10
        let preferredDay = dayCounts.max(by: { $0.value < $1.value })?.key ?? 2
        let averageDuration = durationStats.isEmpty ? 3600 : durationStats.reduce(0, +) / Double(durationStats.count)
        
        return CalendarAnalysis(
            totalEvents: events.count,
            preferredMeetingHour: preferredHour,
            preferredMeetingDay: preferredDay,
            averageMeetingDuration: averageDuration,
            busyDays: dayCounts.filter { $0.value > 2 }.map { $0.key }
        )
    }
    
    func suggestOptimalMeetingTime(for note: StickyNote, within days: Int = 7) -> Date? {
        let analysis = analyzeCalendarPatterns()
        let calendar = Calendar.current
        
        // Start from tomorrow
        guard let startDate = calendar.date(byAdding: .day, value: 1, to: Date()) else { return nil }
        
        for dayOffset in 0..<days {
            guard let candidateDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            
            let dayOfWeek = calendar.component(.weekday, from: candidateDate)
            
            // Skip weekends unless preferred
            if (dayOfWeek == 1 || dayOfWeek == 7) && !analysis.busyDays.contains(dayOfWeek) {
                continue
            }
            
            // Try preferred hour
            if let optimalTime = calendar.date(bySettingHour: analysis.preferredMeetingHour, minute: 0, second: 0, of: candidateDate) {
                // Check if this time slot is free
                if isTimeSlotFree(at: optimalTime, duration: analysis.averageMeetingDuration) {
                    return optimalTime
                }
            }
            
            // Try other available hours if preferred is busy
            for hour in [9, 10, 11, 14, 15, 16] {
                if let alternativeTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: candidateDate) {
                    if isTimeSlotFree(at: alternativeTime, duration: analysis.averageMeetingDuration) {
                        return alternativeTime
                    }
                }
            }
        }
        
        return nil
    }
    
    private func isTimeSlotFree(at date: Date, duration: TimeInterval) -> Bool {
        let endTime = date.addingTimeInterval(duration)
        let predicate = eventStore.predicateForEvents(withStart: date, end: endTime, calendars: nil)
        let conflictingEvents = eventStore.events(matching: predicate)
        return conflictingEvents.isEmpty
    }
    
    // MARK: - Private Helper Methods
    
    private func extractEventTitle(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if !firstLine.isEmpty && firstLine.count < 100 {
            return firstLine
        }
        
        // Extract title from content
        let words = text.components(separatedBy: .whitespacesAndNewlines).prefix(8)
        return words.joined(separator: " ")
    }
    
    private func parseEventDetails(from text: String) -> (location: String?, date: Date?) {
        var location: String?
        var date: Date?
        
        // Extract location
        let locationPattern = "(?:at|@|location:?|venue:?)\\s*([^\\n\\r,]+)"
        if let locationMatch = extractFirstMatch(from: text, pattern: locationPattern) {
            location = locationMatch.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Extract date
        let datePatterns = [
            "(?:on|date:?)\\s*(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})",
            "(?:on|date:?)\\s*((?:monday|tuesday|wednesday|thursday|friday|saturday|sunday))",
            "(next|this)\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"
        ]
        
        for pattern in datePatterns {
            if let dateString = extractFirstMatch(from: text, pattern: pattern) {
                date = parseTimeString(dateString)
                if date != nil { break }
            }
        }
        
        return (location: location, date: date)
    }
    
    private func extractFirstMatch(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        
        if let match = matches.first, match.numberOfRanges > 1 {
            return nsText.substring(with: match.range(at: 1))
        }
        
        return nil
    }
    
    private func parseTimeString(_ timeString: String) -> Date? {
        let formatters = [
            "h:mm a", "H:mm", "h a", "H",
            "EEEE", "E", "MM/dd/yyyy", "M/d/yyyy", "yyyy-MM-dd"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            
            if let date = formatter.date(from: timeString) {
                // If it's just a time, add it to today or tomorrow
                if format.contains("h") || format.contains("H") {
                    let calendar = Calendar.current
                    let now = Date()
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
                    
                    if let todayWithTime = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: now) {
                        // If the time has passed today, schedule for tomorrow
                        if todayWithTime < now {
                            return calendar.date(byAdding: .day, value: 1, to: todayWithTime)
                        } else {
                            return todayWithTime
                        }
                    }
                } else if format.contains("E") {
                    // Day of week - find next occurrence
                    let calendar = Calendar.current
                    let today = Date()
                    let weekday = calendar.component(.weekday, from: date)
                    let todayWeekday = calendar.component(.weekday, from: today)
                    
                    let daysToAdd = (weekday - todayWeekday + 7) % 7
                    return calendar.date(byAdding: .day, value: daysToAdd == 0 ? 7 : daysToAdd, to: today)
                }
                
                return date
            }
        }
        
        return nil
    }
    
    private func generateEventTitle(from action: SmartAction) -> String {
        switch action.type {
        case .email:
            return "Email: \(action.value)"
        case .phone:
            return "Call: \(action.value)"
        case .calendar:
            return action.value
        case .task:
            return "Task: \(action.value)"
        default:
            return "Event: \(action.value)"
        }
    }
    
    private func extractDateFromAction(_ action: SmartAction) -> Date? {
        if action.type == .date {
            return parseTimeString(action.value)
        }
        return nil
    }
    
    private func hasCommonWords(_ text1: String, _ text2: String, minimumCommon: Int) -> Bool {
        let words1 = Set(text1.components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 })
        let words2 = Set(text2.components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 })
        
        let commonWords = words1.intersection(words2)
        return commonWords.count >= minimumCommon
    }
}

// MARK: - Supporting Types

struct EventSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let description: String
    let confidence: Float
    let source: SuggestionSource
    
    enum SuggestionSource {
        case timePattern
        case keywordMatch
        case deadlineDetection
        case similarEvents
        case aiSuggestion
    }
}

struct CalendarAnalysis {
    let totalEvents: Int
    let preferredMeetingHour: Int
    let preferredMeetingDay: Int
    let averageMeetingDuration: TimeInterval
    let busyDays: [Int]
    
    var preferredMeetingDayName: String {
        let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return dayNames[preferredMeetingDay] ?? "Unknown"
    }
    
    var preferredMeetingTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        
        let calendar = Calendar.current
        if let date = calendar.date(bySettingHour: preferredMeetingHour, minute: 0, second: 0, of: Date()) {
            return formatter.string(from: date)
        }
        
        return "\(preferredMeetingHour):00"
    }
    
    var averageDurationString: String {
        let hours = Int(averageMeetingDuration) / 3600
        let minutes = (Int(averageMeetingDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
}