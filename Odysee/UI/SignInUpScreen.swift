//
//  SignInUpScreen.swift
//  Odysee
//
//  Created by Keith Toh on 27/01/2026.
//

import SwiftUI

struct SignInUpScreen: View {
    var showClose: Bool
    var close: () -> Void
    @ObservedObject var model: ViewModel

    let closeRole: ButtonRole = if #available(iOS 26, *) {
        .close
    } else {
        .cancel
    }

    enum Field: Hashable {
        case email
        case password
    }

    @State private var signUp = true
    @State private var passwordStep = false
    @State private var emailVerification = false

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private func passwordField(metrics: GeometryProxy) -> some View {
        SecureField("Password", text: $password)
            .multilineTextAlignment(.center)
            .frame(width: metrics.size.width * 2 / 3)
            .submitLabel(.done)
            .focused($focusedField, equals: .password)
            .opacity(!signUp && !passwordStep ? 0.01 : 1)
            .accessibilityHidden(!signUp && !passwordStep)
    }

    var body: some View {
        ZStack {
            GeometryReader { metrics in
                VStack {
                    Image("spaceman_white")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .padding(.bottom, 32)

                    Text(signUp ? "Join Odysee" : "Log In to Odysee")
                        .padding(.bottom, 32)

                    if !emailVerification {
                        TextField("Email", text: $email)
                            .multilineTextAlignment(.center)
                            .frame(width: metrics.size.width * 2 / 3)
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .email)
                            .opacity(!signUp && passwordStep ? 0.75 : 1)
                            .disabled(!signUp && passwordStep)

                        // Completely replace the password field
                        // to trigger AutoFill to re-detect sign-in vs sign-up
                        if signUp {
                            passwordField(metrics: metrics)
                                .textContentType(.newPassword)
                        } else {
                            passwordField(metrics: metrics)
                                .textContentType(.password)
                        }

                        Button(
                            signUp ? "Sign Up" :
                                passwordStep ? "Sign In" : "Continue",
                            action: submit
                        )
                        .padding(.top, 32)
                        .buttonStyle(.borderedProminent)

                        if !signUp && passwordStep {
                            Button("Use magic link") {
                                Task {
                                    do {
                                        if try await model.emailVerification(email: email) == .emailVerification {
                                            emailVerification = true
                                        }
                                    } catch {
                                        Helper.showError(error: error)
                                    }
                                }
                            }
                            .padding(.top, 32)
                        }
                    } else {
                        Text(
                            "We sent an email to the address you provided. Please click the link in the message to complete email verification and continue using Odysee."
                        )
                        .padding(.bottom, 32)

                        HStack {
                            Button("Resend Email") {
                                Task {
                                    do {
                                        _ = try await model.emailVerification(email: email)
                                    } catch {
                                        Helper.showError(error: error)
                                    }
                                }
                            }

                            Spacer()

                            Button("Start Over") {
                                model.stopEmailVerificationWait()

                                signUp = true
                                passwordStep = false
                                emailVerification = false
                                email = ""
                                password = ""
                                focusedField = .email
                            }
                        }
                        .frame(width: metrics.size.width * 4 / 5)
                    }

                    Spacer()

                    if !emailVerification {
                        Text(signUp ? "Already have an account?" : "Don't have an account?")
                            .padding(.bottom, 32)
                    }

                    Button(signUp ? "Log In" : "Sign Up") {
                        Task<Void, Never> {
                            model.stopEmailVerificationWait()

                            signUp = !signUp

                            passwordStep = false
                            emailVerification = false
                            email = ""
                            password = ""

                            // Needs some time to settle change
                            try? await Task.sleep(nanoseconds: 50_000_000)
                            focusedField = .email
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top)
                .padding(.bottom, 32)
            }

            if showClose {
                Button("Close", systemImage: "xmark", role: closeRole, action: close)
                    .labelStyle(.iconOnly)
                    .padding(.trailing)
                    .padding(.top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .tint(.white)
            }

            ProgressView()
                .controlSize(.large)
                .apply {
                    if model.inProgress {
                        $0
                    } else {
                        $0.hidden()
                    }
                }
        }
        .environment(\.colorScheme, .dark)
        .textFieldStyle(.roundedBorder)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .disabled(model.inProgress)
        .onSubmit(submit)
        .background {
            Image("ua_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
        .ignoresSafeArea(.keyboard)
    }

    private func submit() {
        Task<Void, Never> {
            if signUp {
                if email.isEmpty {
                    focusedField = .email
                } else if password.isEmpty {
                    focusedField = .password
                } else {
                    focusedField = nil
                    do {
                        if try await model.signUp(email: email, password: password) == .emailVerification {
                            emailVerification = true
                        }
                    } catch {
                        Helper.showError(error: error)
                    }
                }
            } else {
                if !passwordStep {
                    do throws(ViewModel.ContinueError) {
                        switch try await model.emailContinue(email: email) {
                        case .password:
                            passwordStep = true
                            // Needs some time to settle change
                            try? await Task.sleep(nanoseconds: 1_000_000)
                            focusedField = .password
                        case .emailVerification:
                            emailVerification = true
                        }
                    } catch {
                        focusedField = .email
                        switch error {
                        case .empty:
                            break
                        case .invalid,
                             .emailVerification:
                            Helper.showError(error: error)
                        }
                    }
                } else {
                    if password.isEmpty {
                        focusedField = .password
                    } else {
                        do {
                            if try await model.signIn(email: email, password: password) == .emailVerification {
                                emailVerification = true
                            }
                        } catch {
                            Helper.showError(error: error)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SignInUpScreen(
        showClose: true,
        close: {},
        model: .init(
            finish: {},
            frRequestStarted: {}, frRequestFinished: {}
        )
    )
}
