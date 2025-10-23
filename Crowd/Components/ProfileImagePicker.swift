//
//  ProfileImagePicker.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import SwiftUI
import PhotosUI

struct ProfileImagePicker: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            VStack {
                if #available(iOS 16.0, *) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        pickerLabel
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                selectedImage = cropToCircle(image: uiImage)
                                dismiss()
                            }
                        }
                    }
                } else {
                    LegacyImagePicker(image: $selectedImage, onImagePicked: {
                        dismiss()
                    })
                }
            }
            .navigationTitle("Choose Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var pickerLabel: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
            
            Text("Select from Photos")
                .font(.headline)
            
            Text("Your photo will be cropped to a circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func cropToCircle(image: UIImage) -> UIImage {
        let size = min(image.size.width, image.size.height)
        let x = (image.size.width - size) / 2
        let y = (image.size.height - size) / 2
        
        let cropRect = CGRect(x: x, y: y, width: size, height: size)
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        
        // Create circular mask
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            context.cgContext.addEllipse(in: rect)
            context.cgContext.clip()
            croppedImage.draw(in: rect)
        }
    }
}

// MARK: - Legacy Image Picker (iOS 15)
struct LegacyImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImagePicked: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: LegacyImagePicker
        
        init(_ parent: LegacyImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = cropToCircle(image: uiImage)
            }
            parent.onImagePicked()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImagePicked()
        }
        
        private func cropToCircle(image: UIImage) -> UIImage {
            let size = min(image.size.width, image.size.height)
            let x = (image.size.width - size) / 2
            let y = (image.size.height - size) / 2
            
            let cropRect = CGRect(x: x, y: y, width: size, height: size)
            
            guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
                return image
            }
            
            let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            return renderer.image { context in
                let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
                context.cgContext.addEllipse(in: rect)
                context.cgContext.clip()
                croppedImage.draw(in: rect)
            }
        }
    }
}

