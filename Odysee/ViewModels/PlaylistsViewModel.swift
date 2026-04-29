//
//  PlaylistsViewModel.swift
//  Odysee
//
//  Created by Keith Toh on 23/04/2026.
//

import Foundation

extension PlaylistsScreen {
    @MainActor
    class ViewModel: ObservableObject {
        static let pageSize = 50

        @Published private(set) var inProgress = false
        @Published private(set) var refreshing = false

        @Published private(set) var builtinCollections = [SharedPreference.Collection]()

        // FIXME: Not properly cleared on switching account
        @Published private(set) var publishedCollections = [SharedPreference.Collection]()
        @Published private(set) var savedCollections = [SharedPreference.Collection]()
        @Published private(set) var unpublishedCollections = [SharedPreference.Collection]()

        init() {
            Task<Void, Never> {
                builtinCollections = Array(await Wallet.shared.builtinCollections.values)

                for await newBuiltinCollections in await Wallet.shared.sBuiltinCollections {
                    builtinCollections = Array(newBuiltinCollections.values)
                }
            }

            Task<Void, Never> {
                await {
                    inProgress = true
                    defer {
                        inProgress = false
                    }

                    do {
                        try await collectionListAll()
                    } catch {
                        Helper.showError(error: error)
                    }

                    unpublishedCollections = Array(await Wallet.shared.unpublishedCollections.values)
                }()

                for await newUnpublishedCollections in await Wallet.shared.sUnpublishedCollections {
                    unpublishedCollections = Array(newUnpublishedCollections.values)
                }
            }

            Task<Void, Never> {
                do {
                    try await collectionClaimSearch(await Wallet.shared.savedCollectionIds)

                    for await newSavedCollectionIds in await Wallet.shared.sSavedCollectionIds {
                        try await collectionClaimSearch(newSavedCollectionIds)
                    }
                } catch {
                    Helper.showError(error: error)
                }
            }
        }

        @Sendable func refresh() async {
            refreshing = true
            defer {
                refreshing = false
            }

            builtinCollections = Array(await Wallet.shared.builtinCollections.values)
            unpublishedCollections = Array(await Wallet.shared.unpublishedCollections.values)

            do {
                try await collectionListAll()
                try await collectionClaimSearch(await Wallet.shared.savedCollectionIds)
            } catch {
                Helper.showError(error: error)
            }
        }

        func createNewPlaylist(title: String) async {
            let now = Int(Date().timeIntervalSince1970)

            await Wallet.shared.addOrSetUnpublished(collection: .init(
                id: UUID().uuidString,
                name: title,
                title: title,
                type: .playlist,
                createdAt: now,
                updatedAt: now,
            ))

            await Wallet.shared.queuePushSync()
        }

        private func collectionListAll() async throws {
            publishedCollections.removeAll(keepingCapacity: true)

            // Limit in case of failure to break
            for page in 0 ... 999 {
                let published = try await BackendMethods.collectionList.call(params: .init(
                    resolve: true,
                    page: page,
                    pageSize: Self.pageSize
                ))

                publishedCollections.append(contentsOf: published.items.compactMap(\.asCollection))

                if published.isLastPage {
                    break
                }
            }
        }

        private func collectionClaimSearch(_ claimIds: [String]) async throws {
            guard claimIds.count > 0 else {
                return
            }

            savedCollections.removeAll(keepingCapacity: true)

            // Limit in case of failure to break
            for page in 0 ... 999 {
                let claimSearch = try await BackendMethods.claimSearch.call(params: .init(
                    page: page,
                    pageSize: Self.pageSize,
                    claimIds: claimIds
                ))

                savedCollections.append(contentsOf: claimSearch.items.compactMap(\.asCollection))

                if claimSearch.isLastPage {
                    break
                }
            }
        }
    }
}
