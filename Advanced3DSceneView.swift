import SwiftUI
import SceneKit
import simd

struct Advanced3DSceneView: UIViewRepresentable {
    let notes: [StickyNote]
    let viewMode: ContentView.View3DMode
    let onNoteSelected: (StickyNote) -> Void
    let onNotePositionChanged: (StickyNote, Position3D) -> Void
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.delegate = context.coordinator
        sceneView.scene = createScene()
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = UIColor.systemBackground
        
        // Setup camera
        setupCamera(in: sceneView.scene!)
        
        // Setup lighting
        setupLighting(in: sceneView.scene!)
        
        // Setup gesture recognizers
        setupGestureRecognizers(for: sceneView, coordinator: context.coordinator)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.notes = notes
        context.coordinator.viewMode = viewMode
        context.coordinator.updateScene(uiView.scene!)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            notes: notes,
            viewMode: viewMode,
            onNoteSelected: onNoteSelected,
            onNotePositionChanged: onNotePositionChanged
        )
    }
    
    private func createScene() -> SCNScene {
        let scene = SCNScene()
        
        // Add environment
        addEnvironment(to: scene)
        
        return scene
    }
    
    private func setupCamera(in scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 5, z: 20)
        cameraNode.eulerAngles = SCNVector3(x: -0.2, y: 0, z: 0)
        
        // Camera properties
        cameraNode.camera?.fieldOfView = 60
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 1000
        
        scene.rootNode.addChildNode(cameraNode)
    }
    
    private func setupLighting(in scene: SCNScene) {
        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor.white
        ambientLight.light?.intensity = 300
        scene.rootNode.addChildNode(ambientLight)
        
        // Directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.color = UIColor.white
        directionalLight.light?.intensity = 800
        directionalLight.position = SCNVector3(x: 10, y: 10, z: 10)
        directionalLight.eulerAngles = SCNVector3(x: -Float.pi/4, y: Float.pi/4, z: 0)
        scene.rootNode.addChildNode(directionalLight)
        
        // Point light for atmosphere
        let pointLight = SCNNode()
        pointLight.light = SCNLight()
        pointLight.light?.type = .omni
        pointLight.light?.color = UIColor.systemBlue
        pointLight.light?.intensity = 200
        pointLight.position = SCNVector3(x: 0, y: 8, z: 0)
        scene.rootNode.addChildNode(pointLight)
    }
    
    private func addEnvironment(to scene: SCNScene) {
        // Add a subtle grid floor
        let floorGeometry = SCNPlane(width: 50, height: 50)
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = UIColor.systemGray6.withAlphaComponent(0.3)
        floorMaterial.isDoubleSided = true
        floorGeometry.materials = [floorMaterial]
        
        let floorNode = SCNNode(geometry: floorGeometry)
        floorNode.eulerAngles = SCNVector3(x: -Float.pi/2, y: 0, z: 0)
        floorNode.position = SCNVector3(x: 0, y: -8, z: 0)
        scene.rootNode.addChildNode(floorNode)
        
        // Add some atmospheric particles
        addParticleEffects(to: scene)
    }
    
    private func addParticleEffects(to scene: SCNScene) {
        let particleSystem = SCNParticleSystem()
        particleSystem.particleImage = UIImage(systemName: "star.fill")
        particleSystem.birthRate = 5
        particleSystem.particleLifeSpan = 10
        particleSystem.particleSize = 0.1
        particleSystem.particleVelocity = 0.5
        particleSystem.emissionDirection = SCNVector3(0, 1, 0)
        particleSystem.spreadingAngle = 45
        particleSystem.particleColor = UIColor.systemBlue.withAlphaComponent(0.6)
        
        let particleNode = SCNNode()
        particleNode.position = SCNVector3(x: 0, y: -5, z: 0)
        particleNode.addParticleSystem(particleSystem)
        scene.rootNode.addChildNode(particleNode)
    }
    
    private func setupGestureRecognizers(for sceneView: SCNView, coordinator: Coordinator) {
        let tapGesture = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        sceneView.addGestureRecognizer(panGesture)
        
        let longPressGesture = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        sceneView.addGestureRecognizer(longPressGesture)
    }
}

// MARK: - Coordinator

extension Advanced3DSceneView {
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var notes: [StickyNote]
        var viewMode: ContentView.View3DMode
        let onNoteSelected: (StickyNote) -> Void
        let onNotePositionChanged: (StickyNote, Position3D) -> Void
        
        private var noteNodes: [UUID: SCNNode] = [:]
        private var selectedNode: SCNNode?
        private var draggedNode: SCNNode?
        private let engine = Advanced3DNotesEngine()
        
        init(notes: [StickyNote], viewMode: ContentView.View3DMode, onNoteSelected: @escaping (StickyNote) -> Void, onNotePositionChanged: @escaping (StickyNote, Position3D) -> Void) {
            self.notes = notes
            self.viewMode = viewMode
            self.onNoteSelected = onNoteSelected
            self.onNotePositionChanged = onNotePositionChanged
            super.init()
        }
        
        func updateScene(_ scene: SCNScene) {
            // Remove existing note nodes
            noteNodes.values.forEach { $0.removeFromParentNode() }
            noteNodes.removeAll()
            
            // Add note nodes based on view mode
            switch viewMode {
            case .spatial:
                addSpatialNotes(to: scene)
            case .clustered:
                addClusteredNotes(to: scene)
            case .timeline:
                addTimelineNotes(to: scene)
            case .mindPalace:
                addMindPalaceNotes(to: scene)
            }
            
            // Add connections between related notes
            addNoteConnections(to: scene)
        }
        
        private func addSpatialNotes(to scene: SCNScene) {
            for note in notes {
                let noteNode = createNoteNode(for: note)
                noteNode.position = SCNVector3(
                    note.position.x,
                    note.position.y,
                    note.position.z
                )
                scene.rootNode.addChildNode(noteNode)
                noteNodes[note.id] = noteNode
            }
        }
        
        private func addClusteredNotes(to scene: SCNScene) {
            let clusters = engine.clusterNotes(notes, algorithm: .hybrid)
            
            for cluster in clusters {
                // Add cluster visualization
                let clusterNode = createClusterNode(for: cluster)
                scene.rootNode.addChildNode(clusterNode)
                
                // Add notes in cluster
                for note in cluster.notes {
                    let noteNode = createNoteNode(for: note)
                    noteNode.position = SCNVector3(
                        note.position.x,
                        note.position.y,
                        note.position.z
                    )
                    scene.rootNode.addChildNode(noteNode)
                    noteNodes[note.id] = noteNode
                }
            }
        }
        
        private func addTimelineNotes(to scene: SCNScene) {
            let timelineNotes = engine.generateTimelineLayout(notes)
            
            // Add timeline path
            let timelinePath = createTimelinePath(for: timelineNotes)
            scene.rootNode.addChildNode(timelinePath)
            
            for note in timelineNotes {
                let noteNode = createNoteNode(for: note)
                noteNode.position = SCNVector3(
                    note.position.x,
                    note.position.y,
                    note.position.z
                )
                scene.rootNode.addChildNode(noteNode)
                noteNodes[note.id] = noteNode
            }
        }
        
        private func addMindPalaceNotes(to scene: SCNScene) {
            let mindPalaceNotes = engine.generateMindPalaceLayout(notes)
            
            // Add room structures
            addMindPalaceRooms(to: scene)
            
            for note in mindPalaceNotes {
                let noteNode = createNoteNode(for: note)
                noteNode.position = SCNVector3(
                    note.position.x,
                    note.position.y,
                    note.position.z
                )
                scene.rootNode.addChildNode(noteNode)
                noteNodes[note.id] = noteNode
            }
        }
        
        private func createNoteNode(for note: StickyNote) -> SCNNode {
            let noteNode = SCNNode()
            
            // Create note geometry based on size
            let size = CGFloat(note.size.scale)
            let geometry = SCNBox(width: size * 2, height: size * 1.5, length: 0.1, chamferRadius: 0.1)
            
            // Create material with note color
            let material = SCNMaterial()
            material.diffuse.contents = note.color.uiColor.withAlphaComponent(0.9)
            material.specular.contents = UIColor.white
            material.shininess = 0.5
            
            // Add glow effect based on mood
            if note.mood == .excited || note.priority == .urgent {
                material.emission.contents = note.mood.color.uiColor.withAlphaComponent(0.3)
            }
            
            geometry.materials = [material]
            noteNode.geometry = geometry
            
            // Add text overlay
            addTextOverlay(to: noteNode, for: note)
            
            // Add photo overlay if available
            if let photo = note.photo {
                addPhotoOverlay(to: noteNode, photo: photo)
            }
            
            // Add interaction indicators
            addInteractionIndicators(to: noteNode, for: note)
            
            // Store reference to the note
            noteNode.name = note.id.uuidString
            
            // Add hover animation
            addHoverAnimation(to: noteNode)
            
            return noteNode
        }
        
        private func addTextOverlay(to noteNode: SCNNode, for note: StickyNote) {
            let text = SCNText(string: note.title.isEmpty ? note.content.prefix(50) : note.title, extrusionDepth: 0.02)
            text.font = UIFont.systemFont(ofSize: 0.3, weight: .medium)
            text.firstMaterial?.diffuse.contents = UIColor.label
            
            let textNode = SCNNode(geometry: text)
            textNode.position = SCNVector3(x: -0.8, y: 0.3, z: 0.06)
            textNode.scale = SCNVector3(0.5, 0.5, 0.5)
            
            noteNode.addChildNode(textNode)
        }
        
        private func addPhotoOverlay(to noteNode: SCNNode, photo: UIImage) {
            let photoGeometry = SCNPlane(width: 1.5, height: 1.0)
            let photoMaterial = SCNMaterial()
            photoMaterial.diffuse.contents = photo
            photoGeometry.materials = [photoMaterial]
            
            let photoNode = SCNNode(geometry: photoGeometry)
            photoNode.position = SCNVector3(x: 0, y: -0.2, z: 0.06)
            
            noteNode.addChildNode(photoNode)
        }
        
        private func addInteractionIndicators(to noteNode: SCNNode, for note: StickyNote) {
            if !note.detectedActions.isEmpty {
                // Add action indicators
                for (index, action) in note.detectedActions.prefix(3).enumerated() {
                    let indicatorGeometry = SCNSphere(radius: 0.1)
                    let indicatorMaterial = SCNMaterial()
                    
                    switch action.type {
                    case .email: indicatorMaterial.diffuse.contents = UIColor.systemBlue
                    case .phone: indicatorMaterial.diffuse.contents = UIColor.systemGreen
                    case .url: indicatorMaterial.diffuse.contents = UIColor.systemPurple
                    case .calendar: indicatorMaterial.diffuse.contents = UIColor.systemRed
                    default: indicatorMaterial.diffuse.contents = UIColor.systemGray
                    }
                    
                    indicatorGeometry.materials = [indicatorMaterial]
                    
                    let indicatorNode = SCNNode(geometry: indicatorGeometry)
                    indicatorNode.position = SCNVector3(x: -0.8 + Float(index) * 0.3, y: -0.6, z: 0.1)
                    
                    noteNode.addChildNode(indicatorNode)
                }
            }
            
            // Priority indicator
            if note.priority == .urgent || note.priority == .high {
                let priorityGeometry = SCNSphere(radius: 0.05)
                let priorityMaterial = SCNMaterial()
                priorityMaterial.diffuse.contents = note.priority.color.uiColor
                priorityMaterial.emission.contents = note.priority.color.uiColor.withAlphaComponent(0.5)
                priorityGeometry.materials = [priorityMaterial]
                
                let priorityNode = SCNNode(geometry: priorityGeometry)
                priorityNode.position = SCNVector3(x: 0.8, y: 0.6, z: 0.1)
                
                // Add pulsing animation for urgent notes
                if note.priority == .urgent {
                    let pulseAction = SCNAction.repeatForever(
                        SCNAction.sequence([
                            SCNAction.scale(to: 1.5, duration: 0.5),
                            SCNAction.scale(to: 1.0, duration: 0.5)
                        ])
                    )
                    priorityNode.runAction(pulseAction)
                }
                
                noteNode.addChildNode(priorityNode)
            }
        }
        
        private func addHoverAnimation(to noteNode: SCNNode) {
            let hoverAction = SCNAction.repeatForever(
                SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.2, z: 0, duration: 2.0),
                    SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 2.0)
                ])
            )
            noteNode.runAction(hoverAction)
        }
        
        private func createClusterNode(for cluster: Advanced3DNotesEngine.NoteCluster) -> SCNNode {
            let clusterNode = SCNNode()
            
            // Create cluster sphere
            let geometry = SCNSphere(radius: CGFloat(cluster.radius))
            let material = SCNMaterial()
            material.diffuse.contents = cluster.color.uiColor.withAlphaComponent(0.1)
            material.transparency = 0.3
            geometry.materials = [material]
            
            clusterNode.geometry = geometry
            clusterNode.position = SCNVector3(
                cluster.center.x,
                cluster.center.y,
                cluster.center.z
            )
            
            // Add cluster label
            let labelText = SCNText(string: cluster.theme, extrusionDepth: 0.02)
            labelText.font = UIFont.systemFont(ofSize: 0.5, weight: .bold)
            labelText.firstMaterial?.diffuse.contents = cluster.color.uiColor
            
            let labelNode = SCNNode(geometry: labelText)
            labelNode.position = SCNVector3(x: 0, y: cluster.radius + 0.5, z: 0)
            labelNode.scale = SCNVector3(0.8, 0.8, 0.8)
            
            clusterNode.addChildNode(labelNode)
            
            return clusterNode
        }
        
        private func createTimelinePath(for notes: [StickyNote]) -> SCNNode {
            let pathNode = SCNNode()
            
            guard notes.count > 1 else { return pathNode }
            
            // Create spline path through note positions
            let positions = notes.map { SCNVector3($0.position.x, $0.position.y, $0.position.z) }
            
            for i in 0..<positions.count-1 {
                let cylinderGeometry = SCNCylinder(radius: 0.02, height: 1.0)
                let cylinderMaterial = SCNMaterial()
                cylinderMaterial.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.6)
                cylinderGeometry.materials = [cylinderMaterial]
                
                let cylinderNode = SCNNode(geometry: cylinderGeometry)
                
                let startPos = positions[i]
                let endPos = positions[i+1]
                let midPos = SCNVector3(
                    (startPos.x + endPos.x) / 2,
                    (startPos.y + endPos.y) / 2,
                    (startPos.z + endPos.z) / 2
                )
                
                cylinderNode.position = midPos
                
                // Calculate orientation
                let direction = SCNVector3(endPos.x - startPos.x, endPos.y - startPos.y, endPos.z - startPos.z)
                let distance = sqrt(direction.x*direction.x + direction.y*direction.y + direction.z*direction.z)
                
                cylinderNode.scale = SCNVector3(1, distance, 1)
                
                pathNode.addChildNode(cylinderNode)
            }
            
            return pathNode
        }
        
        private func addMindPalaceRooms(to scene: SCNScene) {
            let roomPositions: [(Category, Position3D)] = [
                (.work, Position3D(x: -10, y: 0, z: -10)),
                (.personal, Position3D(x: 10, y: 0, z: -10)),
                (.ideas, Position3D(x: 0, y: 5, z: 0)),
                (.reminders, Position3D(x: -10, y: 0, z: 10)),
                (.shopping, Position3D(x: 10, y: 0, z: 10))
            ]
            
            for (category, position) in roomPositions {
                let roomNode = createRoomNode(for: category, at: position)
                scene.rootNode.addChildNode(roomNode)
            }
        }
        
        private func createRoomNode(for category: Category, at position: Position3D) -> SCNNode {
            let roomNode = SCNNode()
            
            // Create room walls (transparent)
            let wallGeometry = SCNBox(width: 8, height: 6, length: 8, chamferRadius: 0.2)
            let wallMaterial = SCNMaterial()
            wallMaterial.diffuse.contents = category.color.uiColor.withAlphaComponent(0.1)
            wallMaterial.transparency = 0.2
            wallGeometry.materials = [wallMaterial]
            
            roomNode.geometry = wallGeometry
            roomNode.position = SCNVector3(position.x, position.y, position.z)
            
            // Add room label
            let labelText = SCNText(string: category.rawValue, extrusionDepth: 0.1)
            labelText.font = UIFont.systemFont(ofSize: 1.0, weight: .bold)
            labelText.firstMaterial?.diffuse.contents = category.color.uiColor
            
            let labelNode = SCNNode(geometry: labelText)
            labelNode.position = SCNVector3(x: 0, y: 3.5, z: 0)
            
            roomNode.addChildNode(labelNode)
            
            return roomNode
        }
        
        private func addNoteConnections(to scene: SCNScene) {
            // Add lines between semantically similar notes
            for i in 0..<notes.count {
                for j in (i+1)..<notes.count {
                    let note1 = notes[i]
                    let note2 = notes[j]
                    
                    // Check if notes should be connected
                    let shouldConnect = note1.category == note2.category ||
                                      note1.tags.contains(where: note2.tags.contains) ||
                                      (note1.mood == note2.mood && note1.mood != .neutral)
                    
                    if shouldConnect {
                        let connectionNode = createConnectionLine(from: note1.position, to: note2.position)
                        scene.rootNode.addChildNode(connectionNode)
                    }
                }
            }
        }
        
        private func createConnectionLine(from start: Position3D, to end: Position3D) -> SCNNode {
            let cylinderGeometry = SCNCylinder(radius: 0.01, height: 1.0)
            let cylinderMaterial = SCNMaterial()
            cylinderMaterial.diffuse.contents = UIColor.systemGray.withAlphaComponent(0.3)
            cylinderGeometry.materials = [cylinderMaterial]
            
            let cylinderNode = SCNNode(geometry: cylinderGeometry)
            
            let midPoint = Position3D(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2,
                z: (start.z + end.z) / 2
            )
            
            cylinderNode.position = SCNVector3(midPoint.x, midPoint.y, midPoint.z)
            
            let distance = start.distance(to: end)
            cylinderNode.scale = SCNVector3(1, distance, 1)
            
            return cylinderNode
        }
        
        // MARK: - Gesture Handlers
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let sceneView = gesture.view as? SCNView else { return }
            
            let location = gesture.location(in: sceneView)
            let hitResults = sceneView.hitTest(location, options: [:])
            
            if let result = hitResults.first {
                if let nodeId = result.node.name,
                   let uuid = UUID(uuidString: nodeId),
                   let note = notes.first(where: { $0.id == uuid }) {
                    
                    // Highlight selected node
                    highlightNode(result.node)
                    
                    onNoteSelected(note)
                }
            }
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let sceneView = gesture.view as? SCNView else { return }
            
            let location = gesture.location(in: sceneView)
            
            switch gesture.state {
            case .began:
                let hitResults = sceneView.hitTest(location, options: [:])
                if let result = hitResults.first {
                    draggedNode = result.node
                    highlightNode(result.node)
                }
                
            case .changed:
                guard let node = draggedNode else { return }
                
                let translation = gesture.translation(in: sceneView)
                let scaleFactor: Float = 0.01
                
                node.position.x += Float(translation.x) * scaleFactor
                node.position.y -= Float(translation.y) * scaleFactor
                
                gesture.setTranslation(.zero, in: sceneView)
                
            case .ended:
                if let node = draggedNode,
                   let nodeId = node.name,
                   let uuid = UUID(uuidString: nodeId),
                   let note = notes.first(where: { $0.id == uuid }) {
                    
                    let newPosition = Position3D(
                        x: node.position.x,
                        y: node.position.y,
                        z: node.position.z
                    )
                    
                    onNotePositionChanged(note, newPosition)
                    unhighlightNode(node)
                }
                
                draggedNode = nil
                
            default:
                break
            }
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let sceneView = gesture.view as? SCNView else { return }
            
            let location = gesture.location(in: sceneView)
            let hitResults = sceneView.hitTest(location, options: [:])
            
            if let result = hitResults.first,
               let nodeId = result.node.name,
               let uuid = UUID(uuidString: nodeId),
               let note = notes.first(where: { $0.id == uuid }) {
                
                // Add haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Show context menu or additional options
                onNoteSelected(note)
            }
        }
        
        private func highlightNode(_ node: SCNNode) {
            selectedNode?.removeAction(forKey: "highlight")
            selectedNode = node
            
            let scaleUp = SCNAction.scale(to: 1.2, duration: 0.2)
            let glow = SCNAction.customAction(duration: 0.2) { node, _ in
                if let geometry = node.geometry {
                    geometry.firstMaterial?.emission.contents = UIColor.systemBlue.withAlphaComponent(0.3)
                }
            }
            
            let highlightAction = SCNAction.group([scaleUp, glow])
            node.runAction(highlightAction, forKey: "highlight")
        }
        
        private func unhighlightNode(_ node: SCNNode) {
            let scaleDown = SCNAction.scale(to: 1.0, duration: 0.2)
            let removeGlow = SCNAction.customAction(duration: 0.2) { node, _ in
                if let geometry = node.geometry {
                    geometry.firstMaterial?.emission.contents = UIColor.clear
                }
            }
            
            let unhighlightAction = SCNAction.group([scaleDown, removeGlow])
            node.runAction(unhighlightAction, forKey: "unhighlight")
        }
    }
}

#Preview {
    let sampleNotes = [
        StickyNote(title: "Sample Note 1", content: "This is a sample note", category: .work),
        StickyNote(title: "Sample Note 2", content: "Another note for testing", category: .personal)
    ]
    
    Advanced3DSceneView(
        notes: sampleNotes,
        viewMode: .spatial,
        onNoteSelected: { _ in },
        onNotePositionChanged: { _, _ in }
    )
}