//
//  ContactUsView.swift
//  Ugly Homes
//
//  Contact Us View - Save submissions to database and send email
//

import SwiftUI

struct ContactUsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: ContactCategory = .feedback
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    enum ContactCategory: String, CaseIterable {
        case advertise = "Advertise"
        case feedback = "Feedback"
        case other = "Other"

        var emailSubject: String {
            switch self {
            case .advertise:
                return "Advertising Inquiry - Houser App"
            case .feedback:
                return "User Feedback - Houser App"
            case .other:
                return "General Inquiry - Houser App"
            }
        }

        var description: String {
            switch self {
            case .advertise:
                return "Interested in advertising opportunities with Houser"
            case .feedback:
                return "Share your thoughts, suggestions, or report issues"
            case .other:
                return "General questions or inquiries"
            }
        }

        var icon: String {
            switch self {
            case .advertise:
                return "megaphone.fill"
            case .feedback:
                return "bubble.left.and.bubble.right.fill"
            case .other:
                return "envelope.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Get in Touch")
                                .font(.title)
                                .fontWeight(.bold)

                            Text("We'd love to hear from you! Choose a category below.")
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)

                        // Category selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What would you like to discuss?")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(ContactCategory.allCases, id: \.self) { category in
                                Button(action: {
                                    selectedCategory = category
                                }) {
                                    HStack(spacing: 16) {
                                        // Icon
                                        ZStack {
                                            Circle()
                                                .fill(selectedCategory == category ? Color.orange : Color.gray.opacity(0.2))
                                                .frame(width: 50, height: 50)

                                            Image(systemName: category.icon)
                                                .font(.system(size: 20))
                                                .foregroundColor(selectedCategory == category ? .white : .gray)
                                        }

                                        // Text
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(category.rawValue)
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            Text(category.description)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .lineLimit(2)
                                        }

                                        Spacer()

                                        // Checkmark
                                        if selectedCategory == category {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedCategory == category ? Color.orange : Color.gray.opacity(0.2), lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)

                        // Message (optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message (Optional)")
                                .font(.headline)

                            Text("Add a brief message to include in your email")
                                .font(.caption)
                                .foregroundColor(.gray)

                            TextEditor(text: $message)
                                .frame(height: 120)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)

                        // Send button
                        Button(action: {
                            submitContactForm()
                        }) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Sending...")
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("Submit")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isSubmitting ? Color.gray : Color.orange)
                            .cornerRadius(12)
                        }
                        .disabled(isSubmitting)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Contact Us")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your message has been sent. We'll get back to you soon!")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    func submitContactForm() {
        isSubmitting = true

        Task {
            do {
                // Get current user info
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                let userEmail = try await SupabaseManager.shared.client.auth.session.user.email ?? ""

                // Get user profile for name
                struct ProfileName: Codable {
                    let username: String
                    let fullName: String?

                    enum CodingKeys: String, CodingKey {
                        case username
                        case fullName = "full_name"
                    }
                }

                let profile: ProfileName = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select("username, full_name")
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value

                let userName = profile.fullName ?? profile.username

                // Map category to database value
                let categoryValue: String
                switch selectedCategory {
                case .advertise:
                    categoryValue = "advertise"
                case .feedback:
                    categoryValue = "feedback"
                case .other:
                    categoryValue = "other"
                }

                // Save to database
                struct ContactSubmission: Codable {
                    let userId: UUID
                    let category: String
                    let message: String?
                    let userEmail: String
                    let userName: String

                    enum CodingKeys: String, CodingKey {
                        case userId = "user_id"
                        case category
                        case message
                        case userEmail = "user_email"
                        case userName = "user_name"
                    }
                }

                struct SubmissionResponse: Codable {
                    let id: UUID
                }

                let submission = ContactSubmission(
                    userId: userId,
                    category: categoryValue,
                    message: message.isEmpty ? nil : message,
                    userEmail: userEmail,
                    userName: userName
                )

                let response: SubmissionResponse = try await SupabaseManager.shared.client
                    .from("contact_submissions")
                    .insert(submission)
                    .select("id")
                    .single()
                    .execute()
                    .value

                print("✅ Contact submission saved - ID: \(response.id)")

                // Send email via Edge Function
                let emailPayload: [String: Any] = [
                    "category": categoryValue,
                    "message": message.isEmpty ? "" : message,
                    "userEmail": userEmail,
                    "userName": userName,
                    "submissionId": response.id.uuidString
                ]

                // Send email via Edge Function
                let emailRequest = URLRequest(url: URL(string: "https://pgezrygzubjieqfzyccy.supabase.co/functions/v1/send-contact-email")!)
                var request = emailRequest
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBnZXpyeWd6dWJqaWVxZnp5Y2N5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE4MzE5NjcsImV4cCI6MjA3NzQwNzk2N30.-AK_lNlPfjdPCyXP2KySnFFZ3D_u5UbczXmcOFD6AA8", forHTTPHeaderField: "Authorization")

                let emailPayloadJSON = try JSONSerialization.data(withJSONObject: emailPayload)
                request.httpBody = emailPayloadJSON

                let (_, urlResponse) = try await URLSession.shared.data(for: request)

                guard let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw NSError(domain: "EmailError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to send email"])
                }

                print("✅ Contact email sent successfully")

                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }

            } catch {
                print("❌ Error submitting contact form: \(error)")
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to send message. Please try again."
                    showError = true
                }
            }
        }
    }
}

#Preview {
    ContactUsView()
}
