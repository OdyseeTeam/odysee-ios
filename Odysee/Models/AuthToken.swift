//
//  AuthToken.swift
//  Odysee
//
//  Created by Keith Toh on 24/12/2025.
//

import Base58Swift
import CryptoKit
import FirebaseCrashlytics
import Foundation

actor AuthToken {
    private static let keyHasRunAfterInstall = "hasRunAfterInstall"
    static let keyAppId = "AppInstallationId"

    private static let shared = AuthToken()

    static var token: String {
        get async {
            return await shared.loadOrGenerate()
        }
    }

    /// userSignOut call will load auth token, if not already loaded\
    /// Loaded token is only used to sign out, then will be reset
    static func reset() async {
        if await shared.loadAuthToken() != nil {
            do {
                _ = try await AccountMethods.userSignOut.call(params: .init())
            } catch {
                // FIXME: This is in init if authenticate fails, can't show
                // FIXME: Just drop as sign out should be idempotent
                // Actually important since failure to sign out leaves an orphaned token
                // When doing manual sign out
                // FIXME: Version that throws
                await Helper.showError(error: error)
            }
        }

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

        // Can be a reinstall after uninstall, in which case UserDefaults is cleared but not Keychain
        // Reset the stored token and delete from Keychain, then generate again
        if UserDefaults.standard.object(forKey: Self.keyHasRunAfterInstall) == nil {
            reset()
            UserDefaults.standard.set(true, forKey: Self.keyHasRunAfterInstall)
            return await tryGenerate()
        }

        if let loaded = loadAuthToken() {
            token = loaded
            return loaded
        }

        return await tryGenerate()
    }

    /// Handles errors and retries
    private func tryGenerate() async -> String {
        while true {
            do {
                return try await generate()
            } catch {
                Crashlytics.crashlytics().recordImmediate(error: error)
                await Helper.showError(error: error)
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    /// Will persist the token to the actor and to Keychain
    private func generate() async throws -> String {
        let appId = if let appId = UserDefaults.standard.string(forKey: Self.keyAppId), !appId.isBlank {
            appId
        } else {
            try Self.generateAppId()
        }

        let userNew = try await AccountMethods.userNew.call(params: .init(appId: appId))

        token = userNew.authToken
        persistAuthToken(token: userNew.authToken)
        return userNew.authToken
    }

    // - MARK: Installation ID

    /// Will persist the ID to UserDefaults
    private static func generateAppId() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard status == errSecSuccess else {
            throw SecurityFrameworkError(status: status)
        }

        let hash = SHA384.hash(data: Data(bytes))
        let appId = Base58.base58Encode(Array(hash.makeIterator()))

        UserDefaults.standard.set(appId, forKey: Self.keyAppId)

        return appId
    }

    struct SecurityFrameworkError: LocalizedError, CustomNSError {
        let status: OSStatus

        var errorDescription: String {
            SecCopyErrorMessageString(status, nil) as String? ?? __("OSStatus \(status)")
        }

        var errorUserInfo: [String: Any] {
            [NSLocalizedDescriptionKey: errorDescription]
        }
    }

    // - MARK: Keychain

    // Report errors but don't throw/crash, because user can just log in again

    enum KeychainError: LocalizedError, CustomNSError {
        case unexpectedPasswordData
        case secError(SecurityFrameworkError)

        var errorDescription: String {
            switch self {
            case .unexpectedPasswordData:
                __("Auth Token from Keychain could not be decoded")
            case let .secError(securityFrameworkError):
                __("Keychain error: \(securityFrameworkError.errorDescription)")
            }
        }

        var errorUserInfo: [String: Any] {
            [NSLocalizedDescriptionKey: errorDescription]
        }
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
            Crashlytics.crashlytics().recordImmediate(error: KeychainError.secError(.init(status: status)))
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
            return nil
        }
        guard status == errSecSuccess else {
            Crashlytics.crashlytics().recordImmediate(error: KeychainError.secError(.init(status: status)))
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
            Crashlytics.crashlytics().recordImmediate(error: KeychainError.secError(.init(status: status)))
            return
        }
    }
}
