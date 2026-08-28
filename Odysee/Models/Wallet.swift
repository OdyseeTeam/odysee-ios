//
//  Wallet.swift
//  Odysee
//
//  Created by Keith Toh on 18/12/2025.
//

import Combine
import Foundation
import TaskGate

@MainActor
class Wallet: ObservableObject {
    static let shared = Wallet()

    /// Protected by `gate`
    private var remoteWalletHash: String?
    @Published private(set) var prefs: SharedPreference
    private let gate = AsyncGate()

    private var sync: Task<Void, Never>?
    private static let syncInterval: UInt64 = 300_000_000_000 // 5 minutes
    private static let syncRetryInterval: UInt64 = 10_000_000_000 // 10 seconds

    private init() {
        // Default, should be replaced by pullSync immediately
        prefs = SharedPreference()

        startSync()
    }

    /// Begins a sync loop, which must either wait on gate or cause others to wait on gate
    /// This way there are no conflicts other than internal state that components copy before saving
    func startSync() {
        guard Lbryio.isSignedIn(), sync == nil else {
            return
        }

        sync = Task {
            while true {
                do {
                    try await pullSync()
                    try await Task.sleep(nanoseconds: Self.syncInterval)
                } catch is CancellationError {
                    return
                } catch {
                    if error.localizedDescription != "authentication required" {
                        Helper.showError(error: error)
                    }

                    do {
                        try await Task.sleep(nanoseconds: Self.syncRetryInterval)
                    } catch {
                        return
                    }
                }
            }
        }
    }

    func stopSync() {
        sync?.cancel()
        sync = nil
    }

    func reset() {
        remoteWalletHash = nil
        // Default, should be replaced by pullSync immediately
        prefs = SharedPreference()
    }

    // MARK: Methods which operate on the global singleton (for shorter code at use)

    static func withSyncedPrefs(_ modify: (inout SharedPreference) -> Void) async {
        await shared.gate.withGate {
            do {
                try await shared.pullSync_()
                modify(&shared.prefs)
                try await shared.pushSync(sharedPreference: shared.prefs)
            } catch {
                Helper.showError(error: error)
            }
        }
    }

    static func withSyncedPrefsGet<Result>(_ modify: (inout SharedPreference) -> Result) async throws -> Result {
        return try await shared.gate.withGate {
            try await shared.pullSync_()
            let result = modify(&shared.prefs)
            try await shared.pushSync(sharedPreference: shared.prefs)
            return result
        }
    }

    /// Provides access to the current `sharedPreference` via `wrappedValue` (`prefs`),
    /// and access to live updates of `SharedPreference` fields via `projectedValue` (`$prefs`).
    @propertyWrapper @MainActor
    struct Prefs {
        var wrappedValue: SharedPreference {
            Wallet.shared.prefs
        }

        /// Allows dynamic member lookup rather than using map+keyPath manually
        @dynamicMemberLookup @MainActor
        struct AsyncSequenceWrapper {
            static let shared = AsyncSequenceWrapper()

            private init() {}

            var all: AsyncPublisher<Published<SharedPreference>.Publisher> {
                Wallet.shared.$prefs.values
            }

            subscript<T>(dynamicMember keyPath: KeyPath<SharedPreference, T> & Sendable) -> AsyncMapSequence<
                AsyncPublisher<Published<SharedPreference>.Publisher>,
                T
            > {
                all.map { $0[keyPath: keyPath] }
            }
        }

        var projectedValue: AsyncSequenceWrapper {
            AsyncSequenceWrapper.shared
        }
    }

    @Prefs static var prefs

    // MARK: - Gated wrapper for pull sync

    func pullSync() async throws {
        try await gate.withGate {
            try await pullSync_()
        }
    }

    // MARK: - Methods called inside gate (ONLY pull/push sync)

    private func pullSync_() async throws {
        let localWalletHash = try await BackendMethods.syncHash.call(params: .init())

        do {
            let walletSync = try await AccountMethods.syncGet.call(
                params: .init(hash: localWalletHash)
            )

            remoteWalletHash = walletSync.hash

            if let data = walletSync.data,
               walletSync.changed || localWalletHash != remoteWalletHash
            {
                _ = try await BackendMethods.syncApply.call(params: .init(data: data, blocking: true))
            }
        } catch let LbryioResponseError.error(_, code) where code == 404 {
            let syncApply = try await BackendMethods.syncApply.call(params: .init())

            let syncSet = try await AccountMethods.syncSet.call(params: .init(
                oldHash: "",
                newHash: syncApply.hash,
                data: syncApply.data
            ))
            remoteWalletHash = syncSet.hash
        }

        let sharedPreferenceGet = try await BackendMethods.sharedPreferenceGet.call(params: .init())

        let needPush = sharedPreferenceGet.shared == nil
        prefs = sharedPreferenceGet.shared ?? SharedPreference()

        if needPush {
            try await pushSync(sharedPreference: prefs)
        }
    }

    private func pushSync(sharedPreference: SharedPreference) async throws {
        _ = try await BackendMethods.sharedPreferenceSet.call(params: .init(value: sharedPreference))

        let syncApply = try await BackendMethods.syncApply.call(params: .init())

        let syncSet = try await AccountMethods.syncSet.call(params: .init(
            oldHash: remoteWalletHash ?? "", newHash: syncApply.hash, data: syncApply.data
        ))
        if syncSet.changed {
            remoteWalletHash = syncSet.hash
        }
    }
}
