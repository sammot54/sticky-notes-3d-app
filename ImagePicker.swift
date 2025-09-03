import SwiftUI
import PhotosUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .camera
        
        // Check if camera is available, fallback to photo library
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .photoLibrary
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

// MARK: - PhotosPicker for iOS 16+

@available(iOS 16.0, *)
struct ModernImagePicker: View {
    @Binding var selectedImage: UIImage?
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Photo")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 300, maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 300, height: 200)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("No image selected")
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Select from Library", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                            onImageSelected(uiImage)
                        }
                    }
                }
                
                Button(action: {
                    // Trigger camera picker
                }) {
                    Label("Take Photo", systemImage: "camera")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(selectedImage == nil)
                }
            }
        }
    }
}

// MARK: - Camera Picker

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        
        init(parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.cameraDevice = .rear
        picker.cameraCaptureMode = .photo
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

// MARK: - Image Source Action Sheet

struct ImageSourceActionSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedImage: UIImage?
    let onImageSelected: (UIImage) -> Void
    
    @State private var showingImagePicker = false
    @State private var showingCameraPicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        EmptyView()
            .actionSheet(isPresented: $isPresented) {
                ActionSheet(
                    title: Text("Select Photo Source"),
                    message: Text("Choose how you'd like to add a photo"),
                    buttons: [
                        .default(Text("Camera")) {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                sourceType = .camera
                                showingCameraPicker = true
                            }
                        },
                        .default(Text("Photo Library")) {
                            sourceType = .photoLibrary
                            showingImagePicker = true
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage, onImageSelected: onImageSelected)
            }
            .sheet(isPresented: $showingCameraPicker) {
                CameraPicker(selectedImage: $selectedImage, onImageCaptured: onImageSelected)
            }
    }
}

// MARK: - Image Editor View

struct ImageEditorView: View {
    @Binding var image: UIImage?
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var saturation: Double = 1
    @State private var originalImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                        .padding()
                } else {
                    Text("No image to edit")
                        .foregroundColor(.gray)
                        .frame(maxHeight: 400)
                }
                
                VStack(spacing: 20) {
                    Group {
                        HStack {
                            Text("Brightness")
                            Spacer()
                            Slider(value: $brightness, in: -1...1, step: 0.1)
                                .frame(width: 200)
                        }
                        
                        HStack {
                            Text("Contrast")
                            Spacer()
                            Slider(value: $contrast, in: 0.5...2, step: 0.1)
                                .frame(width: 200)
                        }
                        
                        HStack {
                            Text("Saturation")
                            Spacer()
                            Slider(value: $saturation, in: 0...2, step: 0.1)
                                .frame(width: 200)
                        }
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 20) {
                        Button("Reset") {
                            brightness = 0
                            contrast = 1
                            saturation = 1
                            image = originalImage
                        }
                        .foregroundColor(.blue)
                        
                        Button("Apply Filter") {
                            applyFilters()
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Edit Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        image = originalImage
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            originalImage = image
        }
        .onChange(of: brightness) { _ in applyFilters() }
        .onChange(of: contrast) { _ in applyFilters() }
        .onChange(of: saturation) { _ in applyFilters() }
    }
    
    private func applyFilters() {
        guard let originalImage = originalImage else { return }
        
        let context = CIContext()
        guard let ciImage = CIImage(image: originalImage) else { return }
        
        var filteredImage = ciImage
        
        // Apply brightness filter
        if brightness != 0 {
            let brightnessFilter = CIFilter(name: "CIColorControls")!
            brightnessFilter.setValue(filteredImage, forKey: kCIInputImageKey)
            brightnessFilter.setValue(brightness, forKey: kCIInputBrightnessKey)
            filteredImage = brightnessFilter.outputImage!
        }
        
        // Apply contrast and saturation filter
        if contrast != 1 || saturation != 1 {
            let colorFilter = CIFilter(name: "CIColorControls")!
            colorFilter.setValue(filteredImage, forKey: kCIInputImageKey)
            colorFilter.setValue(contrast, forKey: kCIInputContrastKey)
            colorFilter.setValue(saturation, forKey: kCIInputSaturationKey)
            filteredImage = colorFilter.outputImage!
        }
        
        guard let cgImage = context.createCGImage(filteredImage, from: filteredImage.extent) else { return }
        
        DispatchQueue.main.async {
            self.image = UIImage(cgImage: cgImage)
        }
    }
}

// MARK: - Multi-Image Picker

struct MultiImagePicker: View {
    @Binding var selectedImages: [UIImage]
    @State private var selectedItems: [PhotosPickerItem] = []
    let maxSelection: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if !selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(selectedImages.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipped()
                                        .cornerRadius(8)
                                    
                                    Button(action: {
                                        selectedImages.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                    }
                                    .offset(x: 8, y: -8)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                if #available(iOS 16.0, *) {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: maxSelection,
                        matching: .images
                    ) {
                        Label("Select Photos", systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .onChange(of: selectedItems) { newItems in
                        Task {
                            var newImages: [UIImage] = []
                            
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    newImages.append(image)
                                }
                            }
                            
                            DispatchQueue.main.async {
                                selectedImages = newImages
                            }
                        }
                    }
                }
                
                if !selectedImages.isEmpty {
                    Text("\(selectedImages.count) of \(maxSelection) photos selected")
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Select Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview Extension

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    func compressed(quality: CGFloat = 0.8) -> Data? {
        return jpegData(compressionQuality: quality)
    }
    
    func cropped(to rect: CGRect) -> UIImage? {
        guard let cgImage = cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}

// MARK: - Image Utility Functions

struct ImageUtils {
    static func processImageForNote(_ image: UIImage, maxSize: CGSize = CGSize(width: 800, height: 600)) -> UIImage? {
        // Resize if needed
        let resizedImage: UIImage
        if image.size.width > maxSize.width || image.size.height > maxSize.height {
            let aspectRatio = image.size.width / image.size.height
            let newSize: CGSize
            
            if aspectRatio > 1 {
                // Landscape
                newSize = CGSize(width: maxSize.width, height: maxSize.width / aspectRatio)
            } else {
                // Portrait
                newSize = CGSize(width: maxSize.height * aspectRatio, height: maxSize.height)
            }
            
            resizedImage = image.resized(to: newSize) ?? image
        } else {
            resizedImage = image
        }
        
        return resizedImage
    }
    
    static func extractDominantColors(from image: UIImage) -> [UIColor] {
        guard let cgImage = image.cgImage else { return [] }
        
        let width = 50
        let height = 50
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        let pixelData = UnsafeMutablePointer<UInt32>.allocate(capacity: width * height)
        defer { pixelData.deallocate() }
        
        let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var colorCounts: [UInt32: Int] = [:]
        
        for i in 0..<(width * height) {
            let pixel = pixelData[i]
            colorCounts[pixel, default: 0] += 1
        }
        
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        
        return sortedColors.prefix(5).compactMap { (pixel, _) in
            let r = CGFloat((pixel >> 24) & 255) / 255.0
            let g = CGFloat((pixel >> 16) & 255) / 255.0
            let b = CGFloat((pixel >> 8) & 255) / 255.0
            
            return UIColor(red: r, green: g, blue: b, alpha: 1.0)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedImage: UIImage?
        
        var body: some View {
            VStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                }
                
                Button("Select Image") {
                    // Preview purposes
                }
            }
        }
    }
    
    return PreviewWrapper()
}