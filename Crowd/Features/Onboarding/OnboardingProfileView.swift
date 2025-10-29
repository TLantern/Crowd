//
//  OnboardingProfileView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI
import PhotosUI

struct OnboardingProfileView: View {
    @Binding var username: String
    @Binding var selectedCampus: String
    @Binding var selectedProfileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCropper = false
    @State private var tempImage: UIImage?
    @State private var isCheckingHandle = false
    @State private var usernameError: String?
    
    let onNext: () -> Void
    
    init(username: Binding<String> = .constant(""), selectedCampus: Binding<String> = .constant("UNT"), selectedProfileImage: Binding<UIImage?> = .constant(nil), onNext: @escaping () -> Void) {
        self._username = username
        self._selectedCampus = selectedCampus
        self._selectedProfileImage = selectedProfileImage
        self.onNext = onNext
        
        // Set default if empty
        if self.selectedCampus.isEmpty {
            self.selectedCampus = "UNT"
        }
    }
    
    var body: some View {
        ZStack {
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .preferredColorScheme(.light)

            VStack(spacing: 20) {
                Spacer()
                
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 24, y: 8)
                    .preferredColorScheme(.light)
                    .overlay(
                        VStack(spacing: 16) {
                            Text("Almost done ✨")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                                .preferredColorScheme(.light)

                            Text("How should friends see you?")
                                .font(.system(size: 16))
                                .foregroundColor(.black.opacity(0.7))

                            // Profile Image Section
                            Button(action: {
                                showingImagePicker = true
                                print("Profile image tapped - open image picker")
                            }) {
                                Group {
                                    if let selectedImage = selectedProfileImage {
                                        Image(uiImage: selectedImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.6))
                                                .frame(width: 100, height: 100)
                                            
                                            VStack(spacing: 8) {
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.black.opacity(0.5))
                                                Text("Add Photo")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.black.opacity(0.5))
                                            }
                                        }
                                    }
                                }
                            }
                            

                            TextField("Ex. Scrappy", text: $username)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.6))
                                )
                                .foregroundColor(.black)

                            Text("Use your real name or keep it mysterious 👀 your choice.")
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.black.opacity(0.7))

                            Menu {
                                Button("UNT") { selectedCampus = "UNT" }
                                
                                Divider()
                                
                                Text("UT Dallas (coming soon)")
                                    .disabled(true)
                                Text("UT Arlington (coming soon)")
                                    .disabled(true)
                                Text("UT Austin (coming soon)")
                                    .disabled(true)
                                Text("UT San Antonio (coming soon)")
                                    .disabled(true)
                                Text("University of Houston (coming soon)")
                                    .disabled(true)
                                Text("Texas State University (coming soon)")
                                    .disabled(true)
                            } label: {
                                HStack {
                                    Text(selectedCampus.isEmpty ? "Campus" : selectedCampus)
                                        .foregroundColor(selectedCampus.isEmpty ? .black.opacity(0.5) : .black)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                }
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.6))
                                )
                            }

                            Button(action: {
                                usernameError = nil
                                let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else {
                                    usernameError = "Enter a username"
                                    return
                                }
                                isCheckingHandle = true
                                let handle = "@" + trimmed.lowercased().replacingOccurrences(of: " ", with: "")
                                Task {
                                    do {
                                        let available = try await UserProfileService.shared.isHandleAvailable(handle)
                                        await MainActor.run {
                                            isCheckingHandle = false
                                            if available {
                                                onNext()
                                            } else {
                                                usernameError = "That username is taken. Choose another."
                                            }
                                        }
                                    } catch {
                                        await MainActor.run {
                                            isCheckingHandle = false
                                            usernameError = "Could not verify username right now. Try again."
                                        }
                                    }
                                }
                            }) {
                                Text("Next →")
                                    .font(.system(size: 18, weight: .medium))
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(Color.white)
                                    )
                                    .foregroundColor(.black)
                            }
                            .disabled(isCheckingHandle)
                            .opacity(isCheckingHandle ? 0.6 : 1.0)
                            
                            if let usernameError = usernameError {
                                Text(usernameError)
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(24)
                    )
                    .padding(.horizontal, 24)
                    .frame(maxHeight: 600)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $tempImage, onImagePicked: {
                if let image = tempImage {
                    // Auto-crop the center of the image
                    selectedProfileImage = cropToCircle(image: image)
                    tempImage = nil
                }
            })
        }
    }
    
    // MARK: - Image Processing
    
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

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onImagePicked: () -> Void
    @Environment(\.dismiss) private var dismiss
    
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
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.selectedImage = uiImage
            }
            picker.dismiss(animated: true)
            parent.onImagePicked()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.onImagePicked()
        }
    }
}

#Preview {
    OnboardingProfileView {
        print("Next tapped")
    }
}

