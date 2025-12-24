//
//  AuthToken.swift
//  Odysee
//
//  Created by Keith Toh on 24/12/2025.
//

import FirebaseCrashlytics
import Foundation

actor AuthToken {
    private static let shared = AuthToken()

    static var token: String {
        get async {
            return await shared.loadOrGenerate()
        }
    }

    static func reset() async {
        await shared.reset()
    }

    private var token: String?

    private func reset() {
        token = nil
        deleteAuthToken()
    }

    /// Returns existing, or loads from Keychain, or generates
    private func loadOrGenerate() async -> String {
        if let token {
            return token
        }

        if let loaded = loadAuthToken() {
            token = loaded
            return loaded
        }

        return await tryGenerate()
    }

    /// Handles errors and retries
    private func tryGenerate() async -> String {
        repeat {
            do {
                return try await generate()
            } catch {
                Crashlytics.crashlytics().recordImmediate(error: error)
                await Helper.showError(error: error)
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
        } while true
    }

    /// Will persist the token to the actor and to Keychain
    private func generate() async throws -> String {
        guard let installationId = Lbry.installationId, !installationId.isBlank else {
            throw LbryioRequestError.runtimeError("The installation ID is not set")
        }

        let userNew = try await LbryioMethods.userNew.call(
            params: .init(appId: installationId),
            authTokenOverride: ""
        )

        token = userNew.authToken
        persistAuthToken(token: userNew.authToken)
        return userNew.authToken
    }

    // - MARK: Keychain

    // Report errors but don't throw/crash, because user can just log in again

    enum KeychainError: Error {
        case noPassword
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
    }

    private func persistAuthToken(token: String) {
        let tokenData = token.data

        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: Lbryio.connectionString,
            kSecValueData as String: tokenData,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            Crashlytics.crashlytics().recordImmediate(error: KeychainError.unhandledError(status: status))
            return
        }
    }

    private func loadAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: Lbryio.connectionString,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            // No need to log this when it's expected first-run behavior
            // Crashlytics.crashlytics().recordImmediate(error: KeychainError.noPassword)
            return nil
        }
        guard status == errSecSuccess else {
            Crashlytics.crashlytics().recordImmediate(error: KeychainError.unhandledError(status: status))
            return nil
        }

        guard let tokenData = item as? Data,
              let token = String(data: tokenData, encoding: .utf8)
        else {
            Crashlytics.crashlytics().recordImmediate(error: KeychainError.unexpectedPasswordData)
            return nil
        }

        return token
    }

    private func deleteAuthToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: Lbryio.connectionString,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Crashlytics.crashlytics().recordImmediate(error: KeychainError.unhandledError(status: status))
            return
        }
    }
}
