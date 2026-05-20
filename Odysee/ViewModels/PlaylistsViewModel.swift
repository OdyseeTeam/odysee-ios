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
        @Published private(set) var editedCollections = [SharedPreference.Collection]()
        @Published private(set) var unpublishedCollections = [SharedPreference.Collection]()

        @Published private(set) var publishedCollections = SharedPreference.CollectionGroup()
        @Published private(set) var savedCollections = [SharedPreference.Collection]()

        init() {
            Task<Void, Never> {
                inProgress = true
                defer {
                    inProgress = false
                }

                do {
                    try await collectionListAll()
                } catch {
                    Helper.showError(error: error)
                }
            }

            Task<Void, Never> {
                builtinCollections = Array(await Wallet.shared.builtinCollections.values)

                for await newBuiltinCollections in await Wallet.shared.$builtinCollections {
                    builtinCollections = Array(newBuiltinCollections.values)
                }
            }

            Task<Void, Never> {
                editedCollections = Array(await Wallet.shared.editedCollections.values)

                for await newEditedCollections in await Wallet.shared.$editedCollections {
                    editedCollections = Array(newEditedCollections.values)
                }
            }

            Task<Void, Never> {
                unpublishedCollections = Array(await Wallet.shared.unpublishedCollections.values)

                for await newUnpublishedCollections in await Wallet.shared.$unpublishedCollections {
                    unpublishedCollections = Array(newUnpublishedCollections.values)
                }
            }

            Task<Void, Never> {
                do {
                    try await collectionClaimSearch(await Wallet.shared.savedCollectionIds)

                    for await newSavedCollectionIds in await Wallet.shared.$savedCollectionIds {
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

            do {
                try await Wallet.shared.pullSync()

                builtinCollections = Array(await Wallet.shared.builtinCollections.values)
                unpublishedCollections = Array(await Wallet.shared.unpublishedCollections.values)

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

        func delete(collection: SharedPreference.Collection, publishedKeepPrivate: Bool = false) {
            Task {
                inProgress = true
                defer {
                    inProgress = false
                }

                switch collection.origin {
                case .saved:
                    await Wallet.shared.removeSavedCollection(collection: collection)
                case .unpublished:
                    await Wallet.shared.removeUnpublished(collection: collection)
                case .edited:
                    await Wallet.shared.removeEdited(collection: collection)
                    fallthrough
                case .published:
                    do {
                        _ = try await BackendMethods.streamAbandon.call(params: .init(
                            claimId: collection.collectionId,
                            blocking: true
                        ))

                        try await collectionListAll()
                    } catch {
                        Helper.showError(message: "Error removing uploaded playlist: \(error.localizedDescription)")
                    }
                case .builtin,
                     .claim,
                     .none:
                    break
                }

                if publishedKeepPrivate {
                    var collection = collection

                    // FIXME: Items not preserved
                    collection.collectionId = UUID().uuidString
                    collection.originalClaim = nil
                    collection.origin = .unpublished

                    if let claimIds = collection.items.claimIds {
                        let claimSearch = try await BackendMethods.claimSearch.call(params: .init(
                            page: 1,
                            pageSize: 999,
                            claimIds: claimIds,
                        ))

                        collection.items.uris = claimSearch.items
                            .sorted(like: claimIds, keyPath: \.claimId, transform: \.self)
                            .compactMap(\.permanentUrl)
                            .compactMap { LbryUri.tryParse(url: $0, requireProto: true) }
                    }

                    await Wallet.shared.addOrSetUnpublished(collection: collection)
                }

                await Wallet.shared.queuePushSync()

                Helper.showMessage(message: "Playlist removed")
            }
        }

        func collectionListAll() async throws {
            publishedCollections.removeAll(keepingCapacity: true)

            // Limit in case of failure to break
            for page in 0 ... 999 {
                let published = try await BackendMethods.collectionList.call(params: .init(
                    resolve: true,
                    page: page,
                    pageSize: Self.pageSize
                ))

                publishedCollections.merge(published.items.compactMap {
                    guard let claimId = $0.claimId,
                          let collection = $0.asCollection(origin: .published)
                    else {
                        return nil
                    }

                    return (claimId, collection)
                }, uniquingKeysWith: { _, last in last })

                if published.isLastPage {
                    break
                }
            }
        }

        private func collectionClaimSearch(_ claimIds: [String]) async throws {
            savedCollections.removeAll(keepingCapacity: true)

            guard claimIds.count > 0 else {
                return
            }

            // Limit in case of failure to break
            for page in 0 ... 999 {
                let claimSearch = try await BackendMethods.claimSearch.call(params: .init(
                    page: page,
                    pageSize: Self.pageSize,
                    claimIds: claimIds
                ))

                savedCollections.append(contentsOf: claimSearch.items.compactMap {
                    $0.asCollection(origin: .saved)
                })

                if claimSearch.isLastPage {
                    break
                }
            }
        }
    }
}
