//
//  SignInUpViewModel.swift
//  Odysee
//
//  Created by Keith Toh on 30/01/2026.
//

import FirebaseAnalytics
import Foundation

extension SignInUpScreen {
    @MainActor
    class ViewModel: ObservableObject {
        let finish: @MainActor () -> Void
        let frRequestStarted: @MainActor () -> Void
        let frRequestFinished: @MainActor () -> Void

        init(
            finish: @escaping @MainActor () -> Void,
            frRequestStarted: @escaping @MainActor () -> Void,
            frRequestFinished: @escaping @MainActor () -> Void
        ) {
            self.finish = finish
            self.frRequestStarted = frRequestStarted
            self.frRequestFinished = frRequestFinished
        }

        @Published private(set) var inProgress = false {
            didSet {
                if inProgress {
                    frRequestStarted()
                } else {
                    frRequestFinished()
                }
            }
        }

        private static let emailVerificationWaitInterval: UInt64 = 5_000_000_000 // 5 seconds
        private var emailVerificationWait: Task<Void, Never>?

        func stopEmailVerificationWait() {
            emailVerificationWait?.cancel()
            emailVerificationWait = nil
        }

        private func startEmailVerificationWait() {
            emailVerificationWait = Task {
                while true {
                    do {
                        let user = try await Lbryio.fetchCurrentUser()

                        if user.hasVerifiedEmail ?? false {
                            finish()

                            return
                        }
                    } catch {
                        Helper.showError(error: error)
                    }

                    do {
                        try await Task.sleep(nanoseconds: Self.emailVerificationWaitInterval)
                    } catch {
                        return
                    }
                }
            }
        }

        enum State {
            case password
            case emailVerification
        }

        func signUp(email: String, password: String) async throws -> State {
            inProgress = true
            defer {
                inProgress = false
            }

            _ = try await AccountMethods.userSignUp.call(params: .init(email: email, password: password))

            startEmailVerificationWait()

            return .emailVerification
        }

        enum ContinueError: LocalizedError {
            case empty
            case invalid(message: String)
            case emailVerification(message: String)

            var errorDescription: String? {
                switch self {
                case .empty:
                    assertionFailure("Empty email should be handled by the UI")
                    return __("No email provided")
                case let .invalid(message),
                     let .emailVerification(message):
                    return message
                }
            }
        }

        func emailContinue(email: String) async throws(ContinueError) -> State {
            inProgress = true
            defer {
                inProgress = false
            }

            guard !email.isEmpty else {
                throw .empty
            }

            do {
                let userExists = try await AccountMethods.userExists.call(params: .init(email: email))

                return userExists.hasPassword ? .password : try await emailVerification(email: email)
            } catch let LbryioResponseError.error(_, code) where code == 412 {
                return try await emailVerification(email: email)
            } catch let LbryioResponseError.error(_, code) where code == 404 {
                throw .invalid(message: __("We can't find that email. Did you mean to sign up?"))
            } catch {
                throw .invalid(message: error.localizedDescription)
            }
        }

        func emailVerification(email: String) async throws(ContinueError) -> State {
            do {
                stopEmailVerificationWait()

                _ = try await AccountMethods.userEmailResendToken.call(params: .init(email: email))

                startEmailVerificationWait()

                return .emailVerification
            } catch {
                throw .emailVerification(message: error.localizedDescription)
            }
        }

        func signIn(email: String, password: String) async throws -> State? {
            inProgress = true
            defer {
                inProgress = false
            }

            do {
                let user = try await AccountMethods.userSignIn.call(params: .init(email: email, password: password))

                Lbryio.currentUser = user
                if let id = user.id {
                    Analytics.setDefaultEventParameters(["user_id": id])
                }

                finish()

                return nil
            } catch let LbryioResponseError.error(_, code) where code == 409 {
                return try await emailVerification(email: email)
            }
        }
    }
}
