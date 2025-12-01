//
//  TermsAgreementView.swift
//  Crowd
//
//  Terms of Use agreement screen shown after account creation.
//

import SwiftUI

struct TermsAgreementView: View {
    @State private var hasAgreed = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let onAccept: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.primary)
                
                Text("Terms of Use")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.top, 8)
            
            // Warning message
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                
                Text("You must agree to our Terms of Use. We have zero tolerance for objectionable or abusive content.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Terms link
            Link("View Terms of Use", destination: URL(string: "https://myapp.com/terms")!)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            
            // Agreement checkbox
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    hasAgreed.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(hasAgreed ? Color.green : Color.gray, lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if hasAgreed {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green)
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Text("I have read and agree to the Terms of Use")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
            
            // Continue button
            Button(action: acceptTerms) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(hasAgreed ? Color.green : Color.gray.opacity(0.3))
                )
                .foregroundColor(.white)
            }
            .disabled(!hasAgreed || isSaving)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func acceptTerms() {
        guard hasAgreed else { return }
        
        isSaving = true
        
        Task {
            do {
                guard let userId = FirebaseManager.shared.getCurrentUserId() else {
                    throw NSError(domain: "TermsAgreement", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }
                
                try await UserProfileService.shared.acceptTerms(userId: userId)
                
                await MainActor.run {
                    isSaving = false
                    onAccept()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}


#Preview {
    TermsAgreementView {
        print("Terms accepted")
    }
}

#Preview("iPhone SE") {
    TermsAgreementView {
        print("Terms accepted")
    }
    .previewDevice("iPhone SE (3rd generation)")
}

#Preview("iPhone 15 Pro Max") {
    TermsAgreementView {
        print("Terms accepted")
    }
    .previewDevice("iPhone 15 Pro Max")
}

