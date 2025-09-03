import Foundation
import simd
import CoreML
import NaturalLanguage

class Advanced3DNotesEngine: ObservableObject {
    
    // MARK: - AI Clustering Types
    
    enum ClusteringAlgorithm {
        case semantic
        case temporal
        case mood
        case category
        case hybrid
    }
    
    struct NoteCluster {
        let id: UUID
        let center: Position3D
        let notes: [StickyNote]
        let theme: String
        let color: NoteColor
        let mood: Mood
        let radius: Float
    }
    
    struct SemanticVector {
        let embedding: [Float]
        let noteId: UUID
        
        func similarity(to other: SemanticVector) -> Float {
            let dotProduct = zip(embedding, other.embedding).map(*).reduce(0, +)
            let magnitude1 = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
            let magnitude2 = sqrt(other.embedding.map { $0 * $0 }.reduce(0, +))
            return dotProduct / (magnitude1 * magnitude2)
        }
    }
    
    // MARK: - Properties
    
    private var semanticVectors: [UUID: SemanticVector] = [:]
    private var clusters: [NoteCluster] = []
    private let nlEmbedding = NLEmbedding.wordEmbedding(for: .english)
    
    // MARK: - Public Methods
    
    func generateOptimalPosition(for note: StickyNote, in existingNotes: [StickyNote]) -> Position3D {
        let semanticVector = createSemanticVector(for: note)
        semanticVectors[note.id] = semanticVector
        
        if existingNotes.isEmpty {
            return Position3D(x: 0, y: 0, z: 0)
        }
        
        // Find the most similar notes
        let similarities = existingNotes.compactMap { existingNote -> (StickyNote, Float)? in
            guard let existingVector = semanticVectors[existingNote.id] else { return nil }
            let similarity = semanticVector.similarity(to: existingVector)
            return (existingNote, similarity)
        }.sorted { $0.1 > $1.1 }
        
        // Position based on similarity
        if let mostSimilar = similarities.first, mostSimilar.1 > 0.7 {
            // Place near similar note with some randomness
            let basePos = mostSimilar.0.position
            let offset = Float.random(in: -2...2)
            return Position3D(
                x: basePos.x + offset,
                y: basePos.y + Float.random(in: -1...1),
                z: basePos.z + offset
            )
        }
        
        // Position based on category clustering
        let categoryNotes = existingNotes.filter { $0.category == note.category }
        if !categoryNotes.isEmpty {
            let avgPosition = averagePosition(of: categoryNotes)
            let offset = Float.random(in: -3...3)
            return Position3D(
                x: avgPosition.x + offset,
                y: avgPosition.y + Float.random(in: -1...1),
                z: avgPosition.z + offset
            )
        }
        
        // Default positioning in a spiral pattern
        let angle = Float(existingNotes.count) * 0.5
        let radius = Float(5.0 + Double(existingNotes.count) * 0.3)
        
        return Position3D(
            x: radius * cos(angle),
            y: Float.random(in: -2...2),
            z: radius * sin(angle)
        )
    }
    
    func clusterNotes(_ notes: [StickyNote], algorithm: ClusteringAlgorithm = .hybrid) -> [NoteCluster] {
        guard !notes.isEmpty else { return [] }
        
        switch algorithm {
        case .semantic:
            return clusterBySemantics(notes)
        case .temporal:
            return clusterByTime(notes)
        case .mood:
            return clusterByMood(notes)
        case .category:
            return clusterByCategory(notes)
        case .hybrid:
            return hybridClustering(notes)
        }
    }
    
    func optimizeLayout(for notes: [StickyNote], in bounds: (width: Float, height: Float, depth: Float)) -> [StickyNote] {
        var optimizedNotes = notes
        let clusters = clusterNotes(notes)
        
        // Apply force-directed layout
        for iteration in 0..<50 {
            for i in optimizedNotes.indices {
                var totalForce = simd_float3(0, 0, 0)
                
                // Repulsion from other notes
                for j in optimizedNotes.indices where i != j {
                    let distance = optimizedNotes[i].position.distance(to: optimizedNotes[j].position)
                    if distance < 5.0 {
                        let direction = simd_float3(
                            optimizedNotes[i].position.x - optimizedNotes[j].position.x,
                            optimizedNotes[i].position.y - optimizedNotes[j].position.y,
                            optimizedNotes[i].position.z - optimizedNotes[j].position.z
                        )
                        let normalizedDirection = simd_normalize(direction)
                        let force = normalizedDirection * (5.0 - distance) * 0.1
                        totalForce += force
                    }
                }
                
                // Attraction to cluster center
                if let cluster = clusters.first(where: { $0.notes.contains(where: { $0.id == optimizedNotes[i].id }) }) {
                    let direction = simd_float3(
                        cluster.center.x - optimizedNotes[i].position.x,
                        cluster.center.y - optimizedNotes[i].position.y,
                        cluster.center.z - optimizedNotes[i].position.z
                    )
                    let distance = length(direction)
                    if distance > cluster.radius {
                        let normalizedDirection = simd_normalize(direction)
                        let force = normalizedDirection * (distance - cluster.radius) * 0.05
                        totalForce += force
                    }
                }
                
                // Apply force with damping
                let dampingFactor: Float = 0.8
                let newPosition = Position3D(
                    x: optimizedNotes[i].position.x + totalForce.x * dampingFactor,
                    y: optimizedNotes[i].position.y + totalForce.y * dampingFactor,
                    z: optimizedNotes[i].position.z + totalForce.z * dampingFactor
                )
                
                // Keep within bounds
                optimizedNotes[i].position = constrainToBounds(newPosition, bounds: bounds)
            }
        }
        
        return optimizedNotes
    }
    
    func generateTimelineLayout(_ notes: [StickyNote]) -> [StickyNote] {
        let sortedNotes = notes.sorted { $0.createdAt < $1.createdAt }
        var layoutNotes = sortedNotes
        
        for (index, _) in layoutNotes.enumerated() {
            let t = Float(index) / Float(max(1, layoutNotes.count - 1))
            let spiralRadius = 8.0 + t * 5.0
            let height = t * 10.0 - 5.0
            let angle = t * Float.pi * 4
            
            layoutNotes[index].position = Position3D(
                x: Float(spiralRadius * cos(Double(angle))),
                y: Float(height),
                z: Float(spiralRadius * sin(Double(angle)))
            )
        }
        
        return layoutNotes
    }
    
    func generateMindPalaceLayout(_ notes: [StickyNote]) -> [StickyNote] {
        let categories = Dictionary(grouping: notes, by: { $0.category })
        var layoutNotes: [StickyNote] = []
        
        let roomPositions: [Category: Position3D] = [
            .work: Position3D(x: -10, y: 0, z: -10),
            .personal: Position3D(x: 10, y: 0, z: -10),
            .ideas: Position3D(x: 0, y: 5, z: 0),
            .reminders: Position3D(x: -10, y: 0, z: 10),
            .shopping: Position3D(x: 10, y: 0, z: 10),
            .health: Position3D(x: 0, y: -3, z: -10),
            .travel: Position3D(x: -5, y: 2, z: 0),
            .education: Position3D(x: 5, y: 2, z: 0),
            .finance: Position3D(x: 0, y: -3, z: 10),
            .general: Position3D(x: 0, y: 0, z: 0)
        ]
        
        for (category, categoryNotes) in categories {
            let roomCenter = roomPositions[category] ?? Position3D.random()
            
            for (index, note) in categoryNotes.enumerated() {
                var noteWithPosition = note
                let angle = Float(index) * 2.0 * Float.pi / Float(categoryNotes.count)
                let radius = Float(2.0 + sqrt(Double(categoryNotes.count)) * 0.5)
                
                noteWithPosition.position = Position3D(
                    x: roomCenter.x + radius * cos(angle),
                    y: roomCenter.y + Float.random(in: -1...1),
                    z: roomCenter.z + radius * sin(angle)
                )
                
                layoutNotes.append(noteWithPosition)
            }
        }
        
        return layoutNotes
    }
    
    func detectMoodFromContent(_ content: String) -> Mood {
        let text = content.lowercased()
        
        // Enhanced mood detection keywords
        let moodKeywords: [Mood: [String]] = [
            .veryPositive: ["amazing", "fantastic", "excellent", "wonderful", "brilliant", "outstanding", "incredible"],
            .positive: ["good", "great", "nice", "happy", "pleased", "satisfied", "glad", "cheerful"],
            .excited: ["excited", "thrilled", "pumped", "energetic", "enthusiastic", "passionate"],
            .creative: ["creative", "innovative", "artistic", "design", "imagine", "brainstorm", "inspiration"],
            .calm: ["peaceful", "calm", "relaxed", "serene", "tranquil", "mindful", "meditate"],
            .analytical: ["analyze", "data", "research", "study", "investigate", "examine", "logical"],
            .urgent: ["urgent", "asap", "immediately", "deadline", "critical", "emergency", "rush"],
            .negative: ["bad", "sad", "disappointed", "frustrated", "annoyed", "upset", "worried"],
            .veryNegative: ["terrible", "awful", "horrible", "devastating", "catastrophic", "furious", "depressed"]
        ]
        
        var moodScores: [Mood: Int] = [:]
        
        for (mood, keywords) in moodKeywords {
            let score = keywords.filter { text.contains($0) }.count
            moodScores[mood] = score
        }
        
        // Find the mood with the highest score
        if let bestMood = moodScores.max(by: { $0.value < $1.value }), bestMood.value > 0 {
            return bestMood.key
        }
        
        // Use NLTagger for sentiment analysis as fallback
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = content
        
        if let sentiment = tagger.tag(at: content.startIndex, unit: .paragraph, scheme: .sentimentScore),
           let score = Float(sentiment.rawValue) {
            switch score {
            case 0.5...1.0: return .veryPositive
            case 0.1..<0.5: return .positive
            case -0.1...0.1: return .neutral
            case -0.5..<(-0.1): return .negative
            case -1.0..<(-0.5): return .veryNegative
            default: return .neutral
            }
        }
        
        return .neutral
    }
    
    // MARK: - Private Methods
    
    private func createSemanticVector(for note: StickyNote) -> SemanticVector {
        let text = note.title + " " + note.content
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        
        var embedding = Array(repeating: Float(0), count: 300) // Standard word embedding size
        var wordCount = 0
        
        for word in words {
            if let wordEmbedding = nlEmbedding?.vector(for: word) {
                for (i, value) in wordEmbedding.enumerated() {
                    if i < embedding.count {
                        embedding[i] += Float(value)
                    }
                }
                wordCount += 1
            }
        }
        
        // Average the embeddings
        if wordCount > 0 {
            for i in embedding.indices {
                embedding[i] /= Float(wordCount)
            }
        }
        
        // Fallback: create a simple feature vector based on note characteristics
        if wordCount == 0 {
            embedding = createFallbackEmbedding(for: note)
        }
        
        return SemanticVector(embedding: embedding, noteId: note.id)
    }
    
    private func createFallbackEmbedding(for note: StickyNote) -> [Float] {
        var embedding = Array(repeating: Float(0), count: 300)
        
        // Encode category
        let categoryIndex = Category.allCases.firstIndex(of: note.category) ?? 0
        embedding[categoryIndex * 10] = 1.0
        
        // Encode mood
        let moodIndex = Mood.allCases.firstIndex(of: note.mood) ?? 0
        embedding[100 + moodIndex * 10] = 1.0
        
        // Encode priority
        embedding[200 + note.priority.rawValue * 10] = 1.0
        
        // Encode text length
        let textLength = Float(note.content.count) / 1000.0 // Normalize
        embedding[250] = min(textLength, 1.0)
        
        // Encode has photo
        embedding[251] = note.hasPhoto ? 1.0 : 0.0
        
        // Encode number of actions
        embedding[252] = min(Float(note.detectedActions.count) / 10.0, 1.0)
        
        return embedding
    }
    
    private func clusterBySemantics(_ notes: [StickyNote]) -> [NoteCluster] {
        // Ensure we have semantic vectors for all notes
        for note in notes {
            if semanticVectors[note.id] == nil {
                semanticVectors[note.id] = createSemanticVector(for: note)
            }
        }
        
        // Simple k-means clustering implementation
        let k = min(max(2, notes.count / 5), 8) // Dynamic cluster count
        return kMeansClustering(notes, k: k)
    }
    
    private func clusterByTime(_ notes: [StickyNote]) -> [NoteCluster] {
        let sortedNotes = notes.sorted { $0.createdAt < $1.createdAt }
        let clusters: [NoteCluster] = []
        
        // Group notes by time intervals (e.g., daily, weekly)
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: sortedNotes) { note in
            calendar.startOfDay(for: note.createdAt)
        }
        
        return groupedByDay.map { (date, dayNotes) in
            let avgPosition = averagePosition(of: dayNotes)
            return NoteCluster(
                id: UUID(),
                center: avgPosition,
                notes: dayNotes,
                theme: DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none),
                color: .blue,
                mood: .neutral,
                radius: Float(sqrt(Double(dayNotes.count))) * 1.5
            )
        }
    }
    
    private func clusterByMood(_ notes: [StickyNote]) -> [NoteCluster] {
        let groupedByMood = Dictionary(grouping: notes, by: { $0.mood })
        
        return groupedByMood.map { (mood, moodNotes) in
            let avgPosition = averagePosition(of: moodNotes)
            return NoteCluster(
                id: UUID(),
                center: avgPosition,
                notes: moodNotes,
                theme: mood.rawValue,
                color: mood.color,
                mood: mood,
                radius: Float(sqrt(Double(moodNotes.count))) * 2.0
            )
        }
    }
    
    private func clusterByCategory(_ notes: [StickyNote]) -> [NoteCluster] {
        let groupedByCategory = Dictionary(grouping: notes, by: { $0.category })
        
        return groupedByCategory.map { (category, categoryNotes) in
            let avgPosition = averagePosition(of: categoryNotes)
            return NoteCluster(
                id: UUID(),
                center: avgPosition,
                notes: categoryNotes,
                theme: category.rawValue,
                color: category.color,
                mood: .neutral,
                radius: Float(sqrt(Double(categoryNotes.count))) * 2.0
            )
        }
    }
    
    private func hybridClustering(_ notes: [StickyNote]) -> [NoteCluster] {
        // Combine multiple clustering approaches
        let semanticClusters = clusterBySemantics(notes)
        let categoryClusters = clusterByCategory(notes)
        let moodClusters = clusterByMood(notes)
        
        // Merge similar clusters from different approaches
        var mergedClusters: [NoteCluster] = []
        
        for semanticCluster in semanticClusters {
            var bestMatch: NoteCluster? = nil
            var bestScore: Float = 0
            
            for categoryCluster in categoryClusters {
                let intersection = Set(semanticCluster.notes.map { $0.id }).intersection(Set(categoryCluster.notes.map { $0.id }))
                let score = Float(intersection.count) / Float(max(semanticCluster.notes.count, categoryCluster.notes.count))
                
                if score > bestScore {
                    bestScore = score
                    bestMatch = categoryCluster
                }
            }
            
            if let match = bestMatch, bestScore > 0.5 {
                // Merge clusters
                let mergedNotes = Array(Set(semanticCluster.notes + match.notes))
                let mergedCluster = NoteCluster(
                    id: UUID(),
                    center: averagePosition(of: mergedNotes),
                    notes: mergedNotes,
                    theme: "\(semanticCluster.theme) • \(match.theme)",
                    color: semanticCluster.color,
                    mood: semanticCluster.mood,
                    radius: Float(sqrt(Double(mergedNotes.count))) * 1.8
                )
                mergedClusters.append(mergedCluster)
            } else {
                mergedClusters.append(semanticCluster)
            }
        }
        
        return mergedClusters
    }
    
    private func kMeansClustering(_ notes: [StickyNote], k: Int) -> [NoteCluster] {
        guard notes.count >= k else {
            return notes.map { note in
                NoteCluster(
                    id: UUID(),
                    center: note.position,
                    notes: [note],
                    theme: note.category.rawValue,
                    color: note.color,
                    mood: note.mood,
                    radius: 1.0
                )
            }
        }
        
        // Initialize centroids randomly
        var centroids = (0..<k).map { _ in
            Array(repeating: Float.random(in: -1...1), count: 300)
        }
        
        var clusters: [[StickyNote]] = Array(repeating: [], count: k)
        
        // K-means iterations
        for _ in 0..<20 {
            clusters = Array(repeating: [], count: k)
            
            // Assign notes to nearest centroid
            for note in notes {
                guard let vector = semanticVectors[note.id] else { continue }
                
                var minDistance: Float = Float.infinity
                var bestCluster = 0
                
                for (i, centroid) in centroids.enumerated() {
                    let distance = euclideanDistance(vector.embedding, centroid)
                    if distance < minDistance {
                        minDistance = distance
                        bestCluster = i
                    }
                }
                
                clusters[bestCluster].append(note)
            }
            
            // Update centroids
            for i in centroids.indices {
                if !clusters[i].isEmpty {
                    let clusterVectors = clusters[i].compactMap { semanticVectors[$0.id] }
                    centroids[i] = averageVector(clusterVectors.map { $0.embedding })
                }
            }
        }
        
        // Convert to NoteCluster objects
        return clusters.enumerated().compactMap { (index, clusterNotes) in
            guard !clusterNotes.isEmpty else { return nil }
            
            let avgPosition = averagePosition(of: clusterNotes)
            let dominantMood = mostFrequentMood(in: clusterNotes)
            let dominantCategory = mostFrequentCategory(in: clusterNotes)
            
            return NoteCluster(
                id: UUID(),
                center: avgPosition,
                notes: clusterNotes,
                theme: "Cluster \(index + 1)",
                color: dominantCategory.color,
                mood: dominantMood,
                radius: Float(sqrt(Double(clusterNotes.count))) * 1.5
            )
        }
    }
    
    private func averagePosition(of notes: [StickyNote]) -> Position3D {
        guard !notes.isEmpty else { return Position3D() }
        
        let sum = notes.reduce(Position3D()) { result, note in
            Position3D(
                x: result.x + note.position.x,
                y: result.y + note.position.y,
                z: result.z + note.position.z
            )
        }
        
        let count = Float(notes.count)
        return Position3D(
            x: sum.x / count,
            y: sum.y / count,
            z: sum.z / count
        )
    }
    
    private func averageVector(_ vectors: [[Float]]) -> [Float] {
        guard !vectors.isEmpty, let first = vectors.first else { return [] }
        
        var result = Array(repeating: Float(0), count: first.count)
        
        for vector in vectors {
            for i in vector.indices {
                result[i] += vector[i]
            }
        }
        
        let count = Float(vectors.count)
        return result.map { $0 / count }
    }
    
    private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return Float.infinity }
        
        let squaredDiffs = zip(a, b).map { ($0 - $1) * ($0 - $1) }
        return sqrt(squaredDiffs.reduce(0, +))
    }
    
    private func mostFrequentMood(in notes: [StickyNote]) -> Mood {
        let moodCounts = Dictionary(grouping: notes, by: { $0.mood })
        return moodCounts.max(by: { $0.value.count < $1.value.count })?.key ?? .neutral
    }
    
    private func mostFrequentCategory(in notes: [StickyNote]) -> Category {
        let categoryCounts = Dictionary(grouping: notes, by: { $0.category })
        return categoryCounts.max(by: { $0.value.count < $1.value.count })?.key ?? .general
    }
    
    private func constrainToBounds(_ position: Position3D, bounds: (width: Float, height: Float, depth: Float)) -> Position3D {
        return Position3D(
            x: max(-bounds.width/2, min(bounds.width/2, position.x)),
            y: max(-bounds.height/2, min(bounds.height/2, position.y)),
            z: max(-bounds.depth/2, min(bounds.depth/2, position.z))
        )
    }
}