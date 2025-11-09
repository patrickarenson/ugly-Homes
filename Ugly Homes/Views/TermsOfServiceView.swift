//
//  TermsOfServiceView.swift
//  Ugly Homes
//
//  Terms of Service Agreement View - Required for App Store Compliance
//

import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var agreedToTerms: Bool
    @State private var hasScrolledToBottom = false
    @State private var checkboxChecked = false

    var onAccept: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Terms of Service")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.horizontal)
                        .padding(.top, 20)

                    Text("Please read and accept our terms to continue")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.bottom, 12)

                    Divider()
                }

                // Terms Content (Scrollable)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            termsContent
                                .padding()

                            // Hidden anchor at the bottom
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                                .onAppear {
                                    hasScrolledToBottom = true
                                }
                        }
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("scroll")).minY
                            )
                        }
                    )
                    .coordinateSpace(name: "scroll")
                }

                Divider()

                // Acceptance Section
                VStack(spacing: 16) {
                    // Checkbox
                    Button(action: {
                        checkboxChecked.toggle()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: checkboxChecked ? "checkmark.square.fill" : "square")
                                .font(.system(size: 24))
                                .foregroundColor(checkboxChecked ? .orange : .gray)

                            Text("I have read and agree to the Terms of Service")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    // Important notice
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))

                        Text("Zero tolerance for objectionable content or abusive behavior")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)

                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(12)
                        }

                        Button(action: {
                            agreedToTerms = true
                            onAccept()
                            dismiss()
                        }) {
                            Text("Accept & Continue")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(checkboxChecked ? Color.orange : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!checkboxChecked)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .background(Color(.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Terms Content
    var termsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("Last Updated: November 7, 2025")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text("Welcome to Housers! By using our app, you agree to these Terms of Service. Please read them carefully.")
                    .font(.body)

                sectionHeader("1. Zero Tolerance Policy for Objectionable Content")

                Text("Housers has ZERO TOLERANCE for objectionable content and abusive behavior.")
                    .fontWeight(.bold)
                    .foregroundColor(.red)

                sectionSubheader("Prohibited Content")

                Text("You may NOT post content that includes:")

                bulletPoint("Harassment, bullying, or targeting individuals")
                bulletPoint("Hate speech or discrimination")
                bulletPoint("Violence, threats, or graphic content")
                bulletPoint("Sexual or explicit material")
                bulletPoint("Content that exploits or endangers children")
                bulletPoint("Illegal activities or scams")
                bulletPoint("False or misleading information")
                bulletPoint("Copyright infringement")
                bulletPoint("Private information without consent")
                bulletPoint("Content promoting self-harm")
            }

            Group {
                sectionSubheader("Prohibited Behavior")

                Text("Users may NOT:")

                bulletPoint("Harass, abuse, or harm other users")
                bulletPoint("Impersonate others")
                bulletPoint("Create multiple accounts to evade bans")
                bulletPoint("Use bots or automated systems")
                bulletPoint("Interfere with the app's functionality")

                sectionHeader("2. Consequences for Violations")

                Text("Housers takes swift action against violations:")

                bulletPoint("First Offense: Content removal and warning")
                bulletPoint("Repeat Offenses: Temporary or permanent ban")
                bulletPoint("Severe Violations: Immediate permanent ban")
                bulletPoint("Illegal Activity: Report to law enforcement")

                Text("We reserve the right to remove any content and terminate any account at our sole discretion without notice.")
                    .font(.callout)
                    .fontWeight(.semibold)
            }

            Group {
                sectionHeader("3. Content Moderation")

                sectionSubheader("Our Commitment")

                bulletPoint("All reports reviewed within 24 hours")
                bulletPoint("Violating content removed promptly")
                bulletPoint("Violators removed from the platform")
                bulletPoint("Continuous monitoring for objectionable content")

                sectionSubheader("Your Responsibility")

                bulletPoint("Report objectionable content immediately")
                bulletPoint("Do not engage with harmful content")
                bulletPoint("Respect other users")
                bulletPoint("Maintain a safe community")
            }

            Group {
                sectionHeader("4. User Content Standards")

                Text("When posting property listings, you must:")

                bulletPoint("Provide accurate and truthful information")
                bulletPoint("Only post properties you have rights to advertise")
                bulletPoint("Include honest photos and descriptions")
                bulletPoint("Comply with fair housing laws")
                bulletPoint("Not discriminate against any protected class")

                Text("When interacting with others:")

                bulletPoint("Be respectful and professional")
                bulletPoint("Provide constructive feedback only")
                bulletPoint("Keep discussions relevant")
                bulletPoint("Do not harass other users")
            }

            Group {
                sectionHeader("5. Account Termination")

                Text("We may suspend or terminate your account if you:")

                bulletPoint("Violate these Terms of Service")
                bulletPoint("Engage in fraudulent or illegal activity")
                bulletPoint("Create a safety or security risk")
                bulletPoint("For any reason at our discretion")

                sectionHeader("6. Age Requirement")

                Text("You must be at least 16 years old to use Housers.")
                    .fontWeight(.semibold)

                sectionHeader("7. Disclaimers")

                Text("Service provided \"as is\" without warranties. We are not responsible for user-generated content. Housers is not a real estate brokerage - consult licensed professionals for transactions.")
                    .font(.callout)

                sectionHeader("8. Your Acknowledgment")

                Text("By accepting, you confirm:")

                bulletPoint("You have read and understood these Terms")
                bulletPoint("You agree to be bound by these Terms")
                bulletPoint("You understand violations may result in termination")
                bulletPoint("You are at least 16 years of age")
                bulletPoint("You will not post objectionable content")
                bulletPoint("You will report violations you encounter")
            }

            Group {
                sectionHeader("9. Contact Information")

                Text("Questions: patrickarenson@gmail.com")
                Text("Report Violations: Use in-app Report feature")
                Text("Legal: patrickarenson@gmail.com")

                Divider()
                    .padding(.vertical, 8)

                Text("© 2025 Housers. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Helper Views
    func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold))
            .padding(.top, 8)
    }

    func sectionSubheader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .padding(.top, 4)
    }

    func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 14))
        }
        .padding(.leading, 8)
    }
}

// MARK: - Scroll Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    TermsOfServiceView(agreedToTerms: .constant(false)) {
        print("Terms accepted")
    }
}
