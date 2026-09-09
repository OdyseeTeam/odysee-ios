//
//  Globals.swift
//  Odysee
//
//  Created by Keith on 08/09/2026.
//

import FirebaseAnalytics
import Foundation

// FIXME: Should sign out flow just deinit and reinit, no need to worry about reset
@dynamicMemberLookup @MainActor
class Globals: ObservableObject {
    static let shared = Globals()
    static subscript<T>(dynamicMember keyPath: KeyPath<Globals, T>) -> T {
        shared[keyPath: keyPath]
    }

    @Published private(set) var user: User?
    @Published private(set) var channels = [Claim]()
    @Published private(set) var walletBalance: WalletBalance?

    private var walletBalanceTask: Task<Void, Never>?
    private static let loadInterval: UInt64 = 10_000_000_000 // 10 seconds

    private init() {
        startWalletBalanceTask()

        Task {
            do {
                try await loadAll()
            } catch {
                // FIXME: authentication required
                Helper.showError(error: error)
            }
        }
    }

    /// Stop wallet balance loop and reset stored values
    func reset() {
        stopWalletBalanceTask()

        user = nil
        channels = []
        walletBalance = nil
    }

    // MARK: - Wallet Balance (updated automatically)

    // FIXME: Call in UAVC startwalletsync?
    func startWalletBalanceTask() {
        guard Lbryio.isSignedIn(), walletBalanceTask == nil else {
            return
        }

        walletBalanceTask = Task {
            while true {
                do {
                    try await loadWalletBalance()
                } catch {
                    // FIXME: Test if needed
                    if error.localizedDescription != "authentication required" {
                        Helper.showError(error: error)
                    }
                }

                do {
                    try await Task.sleep(nanoseconds: Self.loadInterval)
                } catch {
                    return
                }
            }
        }
    }

    private func stopWalletBalanceTask() {
        walletBalanceTask?.cancel()
        walletBalanceTask = nil
    }

    private func loadWalletBalance() async throws {
        let balance = try await BackendMethods.walletBalance.call(params: .init())

        Lbry.walletBalance = balance // FIXME: Remove
        walletBalance = balance
    }

    // MARK: - Loading other (non updating) values

    private func loadAll() async throws {
        channels = try await loadChannels()
        user = try await loadCurrentUser()
    }

    private func loadChannels() async throws -> [Claim] {
        try await BackendMethods.claimList.call(params: .init(
            claimType: [.channel],
            page: 1,
            pageSize: 999,
            resolve: true
        )).items
    }

    // FIXME: Version that updates self.user (or setter that needs to be called [more risky])
    private func loadCurrentUser() async throws -> User {
        let user = try await AccountMethods.userMe.call(params: .init())

        if let id = user.id {
            Analytics.setDefaultEventParameters(["user_id": id])
        }

        return user
    }
}
