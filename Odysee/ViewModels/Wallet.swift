//
//  Wallet.swift
//  Odysee
//
//  Created by Keith Toh on 18/12/2025.
//

import AsyncExtensions
import Foundation

actor Wallet {
    static let shared = Wallet()

    static let syncInterval: UInt64 = 300_000_000_000 // 5 minutes
    static let syncRetryInterval: UInt64 = 10_000_000_000 // 10 seconds

    // MARK: - Public shared preference properties

    // Only channelName, channelClaimId; requireProto = true
    typealias Follow = LbryUri

    typealias NotificationsDisabled = Bool

    typealias Following = [LbryUri: NotificationsDisabled]

    private(set) var following: Following? {
        didSet {
            if following != oldValue {
                followingQueue.send(following)
            }
        }
    }

    private(set) var sFollowing: AsyncShareSequence<AsyncBufferedChannel<Following?>>
    private let followingQueue = AsyncBufferedChannel<Following?>()

    private(set) var blocked: [LbryUri]? {
        didSet {
            if blocked != oldValue {
                blockedQueue.send(blocked)
            }
        }
    }

    private(set) var sBlocked: AsyncShareSequence<AsyncBufferedChannel<[LbryUri]?>>
    private let blockedQueue = AsyncBufferedChannel<[LbryUri]?>()

    private(set) var defaultChannelId: String?

    // MARK: - Sync

    private var localWalletHash: String?
    private var remoteWalletHash: String?

    private var sync: Task<Void, Never>?
    private let pushQueue = AsyncBufferedChannel<Void>()

    private init() {
        sFollowing = followingQueue.share()
        sBlocked = blockedQueue.share()

        Task {
            await startSync()
            await monitorPushQueue()
        }
    }

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
                        await Helper.showError(error: error)
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

        following = nil
        blocked = nil
        defaultChannelId = nil
    }

    func queuePushSync() {
        pushQueue.send(())
    }

    func pullSync() async throws {
        _ = try await pullSync(updateState: true)
    }

    // FIXME: Need to check in progress? With another actor?
    private func pullSync(updateState: Bool) async throws -> SharedPreference {
        let hash = try await BackendMethods.syncHash.call(params: .init())

        localWalletHash = hash

        do {
            let walletSync = try await AccountMethods.syncGet.call(
                params: .init(hash: hash)
            )

            remoteWalletHash = walletSync.hash

            if let data = walletSync.data,
               walletSync.changed || localWalletHash != remoteWalletHash
            {
                let syncApply = try await BackendMethods.syncApply.call(
                    params: .init(data: data, blocking: true)
                )

                localWalletHash = syncApply.hash
            }
        } catch let LbryioResponseError.error(_, code) where code == 404 {
            let syncApply = try await BackendMethods.syncApply.call(params: .init())

            let syncSet = try await AccountMethods.syncSet.call(params: .init(
                oldHash: "",
                newHash: syncApply.hash,
                data: syncApply.data
            ))
            remoteWalletHash = syncSet.hash

            return try await pullSync(updateState: updateState)
        }

        let sharedPreference = try await BackendMethods.sharedPreferenceGet.call(params: .init()).shared

        if updateState {
            following = try sharedPreference.walletFollowing

            blocked = sharedPreference.blocked

            defaultChannelId = sharedPreference.defaultChannelId
        }

        return sharedPreference
    }

    private func monitorPushQueue() async {
        for await _ in pushQueue {
            do {
                try await pushSync()
            } catch {
                await Helper.showError(error: error)

                // TODO: Is it necessary to pause pull sync, so local state isn't overwritten?

                // TODO: Retry push
            }
        }
    }

    private func pushSync() async throws {
        var sharedPreference = try await pullSync(updateState: false)

        if let following {
            sharedPreference.following = following.map {
                SharedPreference.Following(
                    notificationsDisabled: $0.value,
                    uri: $0.key
                )
            }
            sharedPreference.subscriptions = Array(following.keys)
        }

        if let blocked {
            sharedPreference.blocked = blocked
        }

        sharedPreference.defaultChannelId = defaultChannelId

        _ = try await BackendMethods.sharedPreferenceSet.call(params: .init(value: sharedPreference))

        let syncApply = try await BackendMethods.syncApply.call(params: .init())
        localWalletHash = syncApply.hash

        let syncSet = try await AccountMethods.syncSet.call(params: .init(
            oldHash: remoteWalletHash ?? "", newHash: syncApply.hash, data: syncApply.data
        ))
        if syncSet.changed {
            remoteWalletHash = syncSet.hash
        }
    }
}

// MARK: - Following

extension SharedPreference {
    var walletFollowing: Wallet.Following {
        get throws {
            return try Dictionary(
                following.compactMap {
                    guard let channelName = $0.uri.channelName,
                          let claimId = $0.uri.channelClaimId
                    else {
                        return nil
                    }
                    return try (
                        Wallet.buildFollow(channelName: channelName, claimId: claimId),
                        $0.notificationsDisabled
                    )
                },
                uniquingKeysWith: { _, last in last }
            )
        }
    }
}

extension Wallet {
    static func buildFollow(channelName: String, claimId: String) throws -> Follow {
        let channelName = channelName.starts(with: "@") ? channelName : "@\(channelName)"
        return try LbryUri.parse(url: "lbry://\(channelName):\(claimId)", requireProto: true)
    }

    func addOrSetFollowing(claim: Claim, notificationsDisabled: NotificationsDisabled) async {
        await addOrSetFollowingAll(values: [claim: notificationsDisabled])
    }

    func addOrSetFollowingAll(values: [Claim: NotificationsDisabled]) async {
        guard let sharedPreference = try? await pullSync(updateState: false),
              var newFollowing = try? sharedPreference.walletFollowing
        else {
            return
        }

        for (claim, notificationsDisabled) in values {
            guard let channelName = claim.name,
                  channelName.starts(with: "@"),
                  let claimId = claim.claimId,
                  let uri = try? Self.buildFollow(channelName: channelName, claimId: claimId)
            else {
                return
            }

            newFollowing[uri] = notificationsDisabled
        }

        following = newFollowing
    }

    func removeFollowing(claim: Claim) async {
        guard let sharedPreference = try? await pullSync(updateState: false),
              var newFollowing = try? sharedPreference.walletFollowing,
              let channelName = claim.name,
              channelName.starts(with: "@"),
              let claimId = claim.claimId,
              let uri = try? Self.buildFollow(channelName: channelName, claimId: claimId)
        else {
            return
        }

        newFollowing.removeValue(forKey: uri)
        following = newFollowing
    }

    func isFollowing(claim: Claim) -> Bool {
        guard let channelName = claim.name,
              channelName.starts(with: "@"),
              let claimId = claim.claimId,
              let uri = try? Self.buildFollow(channelName: channelName, claimId: claimId)
        else {
            return false
        }

        return following?[uri] != nil
    }

    /// Defaults to true (disabled) if requested following doesn't exist
    static func isNotificationsDisabled(claim: Claim, for following: Following?) -> NotificationsDisabled {
        guard let channelName = claim.name,
              channelName.starts(with: "@"),
              let claimId = claim.claimId,
              let uri = try? buildFollow(channelName: channelName, claimId: claimId)
        else {
            return true
        }

        return following?[uri] ?? true
    }

    /// Defaults to true (disabled) if requested following doesn't exist
    func isNotificationsDisabled(claim: Claim) -> NotificationsDisabled {
        return Self.isNotificationsDisabled(claim: claim, for: following)
    }
}

// MARK: - Blocked

extension Wallet {
    static func buildBlocked(channelName: String, claimId: String) throws -> LbryUri {
        let channelName = channelName.starts(with: "@") ? channelName : "@\(channelName)"
        return try LbryUri.parse(url: "lbry://\(channelName):\(claimId)", requireProto: true)
    }

    func addBlocked(channelName: String, claimId: String) async {
        guard let sharedPreference = try? await pullSync(updateState: false),
              !Lbry.ownChannels.contains(where: { $0.claimId == claimId })
        else {
            return
        }

        var newBlocked = sharedPreference.blocked

        guard let uri = try? Self.buildBlocked(channelName: channelName, claimId: claimId),
              !newBlocked.contains(uri)
        else {
            return
        }

        newBlocked.append(uri)
        blocked = newBlocked
    }

    func removeBlocked(claimId: String) async {
        guard let sharedPreference = try? await pullSync(updateState: false) else {
            return
        }

        var newBlocked = sharedPreference.blocked

        newBlocked.removeAll { $0.claimId == claimId }
        blocked = newBlocked
    }

    func isBlocked(claimId: String) -> Bool {
        return blocked?.map(\.claimId).contains(claimId) ?? false
    }
}

// MARK: - Default Channel

extension Wallet {
    func setDefaultChannelId(channelId: String) {
        defaultChannelId = channelId
    }
}
