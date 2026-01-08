//
//  Wallet.swift
//  Odysee
//
//  Created by Keith Toh on 18/12/2025.
//

import AsyncAlgorithms
import Combine
import Foundation

actor Wallet {
    static let shared = Wallet()

    static let syncInterval: UInt64 = 300_000_000_000 // 5 minutes
    static let syncRetryInterval: UInt64 = 10_000_000_000 // 10 seconds

    @Published var following: Following = [:]

    private var localWalletHash: String?
    private var remoteWalletHash: String?

    private var sync: Task<Void, Never>?
    private var pushQueue = AsyncChannel<Void>()

    private init() {
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
                } catch {
                    if !(error is CancellationError) &&
                        (error as? LbryApiResponseError)?.localizedDescription != "authentication required"
                    {
                        await Helper.showError(error: error)
                    }
                    try? await Task.sleep(nanoseconds: Self.syncRetryInterval)
                }
            }
        }
    }

    func stopSync() {
        sync?.cancel()
        sync = nil
    }

    func queuePushSync() async {
        await pushQueue.send(())
    }

    private func pullSync() async throws {
        _ = try await pullSync(updateState: true)
    }

    // FIXME: Need to check in progress? With another actor?
    private func pullSync(updateState: Bool) async throws -> SharedPreference {
        let hash = try await LbryMethods.syncHash.call(params: .init())

        localWalletHash = hash

        // FIXME: needs new wallet?
        // Handle, nil data for sync_apply
        let walletSync = try await LbryioMethods.syncGet.call(
            params: .init(hash: hash)
        )

        remoteWalletHash = walletSync.hash

        if let data = walletSync.data,
           walletSync.changed || localWalletHash != remoteWalletHash
        {
            let syncApply = try await LbryMethods.syncApply.call(
                params: .init(data: data, blocking: true)
            )

            localWalletHash = syncApply.hash
        }

        let sharedPreference = try await LbryMethods.sharedPreferenceGet.call(params: .init())

        if updateState {
            following = try sharedPreference.following.reduce(into: Following()) {
                guard let channelName = $1.uri.channelName,
                      let claimId = $1.uri.channelClaimId
                else {
                    return
                }
                try $0[LbryUri.parse(
                    url: "lbry://@\(channelName):\(claimId)", requireProto: true
                )] = $1.notificationsDisabled
            }
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

        sharedPreference.following = following.map {
            SharedPreference.Following(
                notificationsDisabled: $0.value,
                uri: $0.key
            )
        }
        sharedPreference.subscriptions = Array(following.keys)

        _ = try await LbryMethods.sharedPreferenceSet.call(params: .init(value: sharedPreference))

        let syncApply = try await LbryMethods.syncApply.call(params: .init())
        localWalletHash = syncApply.hash

        let syncSet = try await LbryioMethods.syncSet.call(params: .init(
            oldHash: remoteWalletHash ?? "", newHash: syncApply.hash, data: syncApply.data
        ))
        if syncSet.changed {
            remoteWalletHash = syncSet.hash
        }
    }
}
