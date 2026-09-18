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

    @Published private(set) var inProgress = false

    private var walletBalanceTask: Task<Void, Never>?
    private static let loadInterval: UInt64 = 10_000_000_000 // 10 seconds

    private var notificationsWebsocketTask: Task<Void, Never>?

    private init() {}

    /// Stop wallet balance loop and reset stored values
    private func reset() {
        stopWalletBalanceTask()
        walletBalance = .zero

        stopNotificationsWebsocketTask()
        notifications = []

        channels = []
    }

    // MARK: - Wallet Balance (updated automatically)

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

    // MARK: - Getters & Mutators

    func loadCurrentUser() async throws {
        inProgress = true
        defer {
            inProgress = false
        }

        user = try await AccountMethods.userMe.call(params: .init())

        try await onUserUpdated()
    }

    func signInUser(params: UserSignInUpParams) async throws {
        inProgress = true
        defer {
            inProgress = false
        }

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

                startNotificationsWebsocketTask()
            } else {
                reset()
            }
        } else {
            Analytics.setDefaultEventParameters([:])

            reset()
        }
    }

    // MARK: - Notifications

    // swift-format-ignore
    // Initialized once with static value
    private static let wsUrl = URL(string: "wss://sockety.odysee.tv/ws/internal")!
    private var notificationsWebsocket: URLSessionWebSocketTask?

    private static let pendingNotification = "pending_notification"
    private struct WebsocketData: Decodable {
        var type: String
    }

    /// No-op before iOS 16
    private func startNotificationsWebsocketTask() {
        guard Account.signedIn, notificationsWebsocketTask == nil else {
            return
        }

        if #available(iOS 16, *) {
            notificationsWebsocketTask = Task {
                let url = Self.wsUrl.appending(queryItems: [.init(name: "id", value: await AuthToken.token)])
                let websocket = URLSession.shared.webSocketTask(with: url)
                notificationsWebsocket = websocket
                websocket.resume()

                do {
                    while true {
                        let message = try await websocket.receive()

                        guard case let .string(json) = message,
                              let data = try? JSONDecoder().decode(WebsocketData.self, from: json.data),
                              data.type == Self.pendingNotification
                        else {
                            continue
                        }

                        await reloadNotifications()
                    }
                } catch is CancellationError {
                    return
                } catch {
                    Helper.showError(error: error)
                }
            }
        }
    }

    private func stopNotificationsWebsocketTask() {
        notificationsWebsocket?.cancel()
        notificationsWebsocketTask?.cancel()
        notificationsWebsocketTask = nil
    }

    @Sendable func reloadNotifications() async {
        inProgress = true
        defer {
            inProgress = false
        }

        do {
            notifications = try await loadNotifications()
        } catch {
            Helper.showError(error: error)
        }
    }

    private func loadNotifications() async throws -> [Notification] {
        try await AccountMethods.notificationList.call(params: .init())
    }

    /// Doesn't set `inProgress` as it has no effect on UI or logic
    func markAllNotificationsSeen() async {
        try? await Task.sleep(nanoseconds: 100_000_000_000)

        let ids = notifications.filter { !$0.isSeen }.map(\.id)

        guard ids.count > 0 else { return }

        do {
            _ = try await AccountMethods.notificationEdit.call(params: .init(
                notificationIds: ids, isSeen: true
            ))
        } catch {
            Helper.showError(error: error)
        }

        notifications[mutatingAll: \.isSeen] = true
    }

    func markAllNotificationsRead() async {
        inProgress = true
        defer {
            inProgress = false
        }

        let ids = notifications.filter { !$0.isRead }.map(\.id)

        guard ids.count > 0 else { return }

        do {
            _ = try await AccountMethods.notificationEdit.call(params: .init(
                notificationIds: ids, isRead: true, isSeen: true
            ))
        } catch {
            Helper.showError(error: error)
        }

        notifications[mutatingAll: \.isRead] = true
        notifications[mutatingAll: \.isSeen] = true
    }

    func markNotificationReadIfNeeded(notification: Notification) async throws {
        guard !notification.isRead else { return }

        inProgress = true
        defer {
            inProgress = false
        }

        _ = try await AccountMethods.notificationEdit.call(params: .init(
            notificationIds: [notification.id], isRead: true, isSeen: true
        ))

        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            notifications[index].isSeen = true
        }
    }

    func deleteNotifications(at offsets: IndexSet) {
        Task {
            let ids = offsets.map { notifications[$0].id }

            inProgress = true
            defer {
                inProgress = false
            }

            do {
                let _ = try await AccountMethods.notificationDelete.call(params: .init(notificationIds: ids))
            } catch {
                Helper.showError(error: error)
            }

            notifications.remove(atOffsets: offsets)
        }
    }
}
