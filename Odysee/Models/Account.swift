//
//  Account.swift
//  Odysee
//
//  Created by Keith on 08/09/2026.
//

import FirebaseAnalytics
import Foundation

@dynamicMemberLookup @MainActor
class Account: ObservableObject {
    static let shared = Account()
    static subscript<T>(dynamicMember keyPath: KeyPath<Account, T>) -> T {
        shared[keyPath: keyPath]
    }

    @Published private(set) var user: User?
    // FIXME: Make sure updated often enough (and after channel operations etc)
    // FIXME: Check use sites
    @Published private(set) var channels = [Claim]()
    @Published private(set) var notifications = [Notification]()
    @Published private(set) var walletBalance: WalletBalance = .zero

    private var walletBalanceTask: Task<Void, Never>?
    private static let loadInterval: UInt64 = 10_000_000_000 // 10 seconds

    private init() {}

    // FIXME: Called by user updated; don't clear user
    /// Stop wallet balance loop and reset stored values
    private func reset() {
        stopWalletBalanceTask()
        walletBalance = .zero

        channels = []
        notifications = []
    }

    // MARK: - Wallet Balance (updated automatically)

    // FIXME: Call in UAVC startwalletsync?
    /// Loads wallet balance once, causing caller to wait for data to be available, then begins a loading loop
    private func startWalletBalanceTask() async throws {
        guard Account.signedIn, walletBalanceTask == nil else {
            return
        }

        try await loadWalletBalance()

        walletBalanceTask = Task {
            while true {
                do {
                    try await Task.sleep(nanoseconds: Self.loadInterval)
                } catch {
                    return
                }

                do {
                    try await loadWalletBalance()
                } catch {
                    // FIXME: Test if needed
                    if error.localizedDescription != "authentication required" {
                        Helper.showError(error: error)
                    }
                }
            }
        }
    }

    private func stopWalletBalanceTask() {
        walletBalanceTask?.cancel()
        walletBalanceTask = nil
    }

    private func loadWalletBalance() async throws {
        walletBalance = try await BackendMethods.walletBalance.call(params: .init())
    }

    // MARK: - Loading other (non updating) values

    private func loadChannels() async throws -> [Claim] {
        try await BackendMethods.claimList.call(params: .init(
            claimType: [.channel],
            page: 1,
            pageSize: 999,
            resolve: true
        )).items
    }

    private func loadNotifications() async throws -> [Notification] {
        try await AccountMethods.notificationList.call(params: .init())
    }

    // MARK: - Getters & Mutators

    func loadCurrentUser() async throws {
        user = try await AccountMethods.userMe.call(params: .init())

        try await onUserUpdated()
    }

    func signInUser(params: UserSignInUpParams) async throws {
        user = try await AccountMethods.userSignIn.call(params: params)

        try await onUserUpdated()
    }

    var signedIn: Bool {
        if let user {
            user.hasVerifiedEmail
        } else {
            false
        }
    }

    // MARK: - Side effects

    private func onUserUpdated() async throws {
        if let user {
            Analytics.setDefaultEventParameters(["user_id": user.id])

            if signedIn {
                async let channels = loadChannels()
                async let notifications = loadNotifications()
                async let wB = startWalletBalanceTask()
                async let w = Wallet.shared.startSync()

                (
                    self.channels,
                    self.notifications,
                    _,
                    _
                ) = try await (
                    channels,
                    notifications,
                    wB,
                    w
                )
            } else {
                reset()
            }
        } else {
            Analytics.setDefaultEventParameters([:])

            reset()
        }
    }
}
