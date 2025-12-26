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

    // MARK: Sync

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

        if updateState {}

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
        let sharedPreference = try await pullSync(updateState: false)

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
