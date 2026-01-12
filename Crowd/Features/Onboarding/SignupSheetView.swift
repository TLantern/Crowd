//
//  SignupSheetView.swift
//  Crowd
//
//  Minimal signup modal that appears at moment of intent.
//  Only includes: Email / Apple / Google
//  Campus is prefilled from earlier selection.
//  NO interests during signup - those are optional and come later.
//
//  RATIONALE:
//  - Minimal friction at point of conversion
//  - Campus already known from onboarding
//  - Interests are optional and don't block usage
//

import SwiftUI
import AuthenticationServices
import FirebaseAuth

struct SignupSheetView: View {
    @AppStorage("selectedCampusId") private var selectedCampusId: String = "UNT"
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var displayName: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showingEmailForm: Bool = false
    @State private var isSignUp: Bool = true // Toggle between sign up and sign in
    
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: 0xF5F5F5)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView
                        
                        // Campus indicator (prefilled)
                        campusIndicator
                        
                        if showingEmailForm {
                            // Email form
                            emailFormView
                        } else {
                            // Social sign-in buttons
                            socialButtonsView
                        }
                        
                        // Error message
                        if let error = errorMessage {
                            errorView(error)
                        }
                        
                        // Terms
                        termsView
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Track cancellation
                        AnalyticsService.shared.track("signup_sheet_cancelled", props: [:])
                        onCancel()
                    }
                    .foregroundColor(.gray)
                }
            }
            .disabled(isLoading)
        }
        .onAppear {
            AnalyticsService.shared.screenView("signup_sheet")
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image("CrowdText")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 65)
            
            Text("Join the Crowd")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
            
            Text("Create an account to save events and pull up")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Campus Indicator
    
    private var campusIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: 0x02853E))
            
            Text(campusDisplayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: 0x02853E))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: 0x02853E).opacity(0.1))
        )
    }
    
    private var campusDisplayName: String {
        switch selectedCampusId {
        case "UNT": return "University of North Texas"
        case "UTD": return "UT Dallas"
        case "UTA": return "UT Arlington"
        case "UT": return "UT Austin"
        default: return selectedCampusId
        }
    }
    
    // MARK: - Social Buttons View
    
    private var socialButtonsView: some View {
        VStack(spacing: 12) {
            // Sign in with Apple
            SignInWithAppleButton(.signUp) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(12)
            
            // Sign in with Google
            Button(action: handleGoogleSignIn) {
                HStack(spacing: 12) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 20))
                    Text("Continue with Google")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Divider
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)
            
            // Email option
            Button(action: { showingEmailForm = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 18))
                    Text("Continue with Email")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(hex: 0x02853E))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Email Form View
    
    private var emailFormView: some View {
        VStack(spacing: 16) {
            // Back button
            HStack {
                Button(action: { showingEmailForm = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(Color(hex: 0x02853E))
                }
                Spacer()
            }
            
            // Toggle sign up / sign in
            Picker("", selection: $isSignUp) {
                Text("Sign Up").tag(true)
                Text("Sign In").tag(false)
            }
            .pickerStyle(.segmented)
            
            // Display name (only for sign up)
            if isSignUp {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Display Name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                    
                    TextField("Your name", text: $displayName)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textContentType(.name)
                        .autocapitalization(.words)
                }
            }
            
            // Email
            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                
                TextField("your@email.edu", text: $email)
                    .textFieldStyle(RoundedTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            // Password
            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                
                SecureField("••••••••", text: $password)
                    .textFieldStyle(RoundedTextFieldStyle())
                    .textContentType(isSignUp ? .newPassword : .password)
            }
            
            // Submit button
            Button(action: handleEmailAuth) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(hex: 0x02853E))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading || !isFormValid)
            .opacity(isFormValid ? 1.0 : 0.6)
        }
    }
    
    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        let nameValid = !isSignUp || displayName.count >= 2
        return emailValid && passwordValid && nameValid
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.red)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
        )
    }
    
    // MARK: - Terms View
    
    private var termsView: some View {
        Text("By signing up, you agree to our Terms of Service and Privacy Policy.")
            .font(.system(size: 11))
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
    
    // MARK: - Auth Handlers
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                errorMessage = "Failed to get Apple ID credentials"
                return
            }
            
            isLoading = true
            errorMessage = nil
            
            Task {
                do {
                    let credential = OAuthProvider.credential(
                        providerID: AuthProviderID.apple,
                        idToken: tokenString,
                        rawNonce: nil
                    )
                    
                    let authResult = try await FirebaseManager.shared.auth.signIn(with: credential)
                    let userId = authResult.user.uid
                    
                    // Get display name from Apple
                    var name = "Crowd User"
                    if let fullName = appleIDCredential.fullName {
                        let givenName = fullName.givenName ?? ""
                        let familyName = fullName.familyName ?? ""
                        name = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
                        if name.isEmpty { name = "Crowd User" }
                    }
                    
                    // Create profile
                    try await createUserProfile(userId: userId, displayName: name)
                    
                    await MainActor.run {
                        isLoading = false
                        AnalyticsService.shared.track("signup_completed", props: [
                            "method": "apple",
                            "campus": selectedCampusId
                        ])
                        onComplete()
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
            
        case .failure(let error):
            // User cancelled or other error
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func handleGoogleSignIn() {
        // Google Sign-In requires additional setup with Google SDK
        // For now, show a message that it's coming soon
        errorMessage = "Google Sign-In coming soon! Please use Apple or Email."
        
        AnalyticsService.shared.track("google_signin_attempted", props: [
            "campus": selectedCampusId
        ])
    }
    
    private func handleEmailAuth() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if isSignUp {
                    // Create new account
                    let authResult = try await FirebaseManager.shared.auth.createUser(
                        withEmail: email,
                        password: password
                    )
                    let userId = authResult.user.uid
                    
                    // Create profile
                    try await createUserProfile(userId: userId, displayName: displayName)
                    
                    await MainActor.run {
                        isLoading = false
                        AnalyticsService.shared.track("signup_completed", props: [
                            "method": "email",
                            "campus": selectedCampusId
                        ])
                        onComplete()
                    }
                } else {
                    // Sign in existing account
                    let authResult = try await FirebaseManager.shared.auth.signIn(
                        withEmail: email,
                        password: password
                    )
                    
                    await MainActor.run {
                        isLoading = false
                        AnalyticsService.shared.track("signin_completed", props: [
                            "method": "email",
                            "campus": selectedCampusId
                        ])
                        onComplete()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = friendlyErrorMessage(error)
                }
            }
        }
    }
    
    private func createUserProfile(userId: String, displayName: String) async throws {
        // Create profile with campus prefilled
        // NO interests - those are optional and come later
        try await UserProfileService.shared.createProfile(
            userId: userId,
            displayName: displayName,
            campus: selectedCampusId,
            interests: []  // Empty - interests are optional post-signup
        )
    }
    
    private func friendlyErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        
        switch nsError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "This email is already registered. Try signing in instead."
        case AuthErrorCode.invalidEmail.rawValue:
            return "Please enter a valid email address."
        case AuthErrorCode.weakPassword.rawValue:
            return "Password must be at least 6 characters."
        case AuthErrorCode.wrongPassword.rawValue:
            return "Incorrect password. Please try again."
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found with this email. Try signing up instead."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection."
        default:
            return error.localizedDescription
        }
    }
}

// MARK: - Rounded Text Field Style

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    SignupSheetView(
        onComplete: { print("Complete") },
        onCancel: { print("Cancel") }
    )
}
