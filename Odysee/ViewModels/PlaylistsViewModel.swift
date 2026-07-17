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
                do {
                    for await savedCollectionIds in Wallet.$prefs.savedCollectionIds {
                        try await collectionClaimSearch(savedCollectionIds)
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

                try await collectionListAll()
                try await collectionClaimSearch(Wallet.prefs.savedCollectionIds)
            } catch {
                Helper.showError(error: error)
            }
        }

        func createNewPlaylist(title: String) async {
            await Wallet.withSyncedPrefs { prefs in
                prefs.addOrSetUnpublishedCollection(collection: Self.newPlaylist(title: title))
            }
        }

        static func newPlaylist(title: String) -> SharedPreference.Collection {
            let now = Int(Date().timeIntervalSince1970)
            return .init(
                id: UUID().uuidString,
                name: title,
                title: title,
                type: .playlist,
                createdAt: now,
                updatedAt: now,

                origin: .unpublished,
            )
        }

        func delete(collection: SharedPreference.Collection, publishedKeepPrivate: Bool = false) {
            Task {
                inProgress = true
                defer {
                    inProgress = false
                }

                var privateCopy: SharedPreference.Collection?

                do {
                    if publishedKeepPrivate && collection.isPublished {
                        privateCopy = collection

                        privateCopy?.collectionId = UUID().uuidString
                        privateCopy?.originalClaim = nil
                        privateCopy?.origin = .unpublished

                        if let claimIds = privateCopy?.items.claimIds {
                            let claimSearch = try await BackendMethods.claimSearch.call(params: .init(
                                page: 1,
                                pageSize: 999,
                                claimIds: claimIds,
                            ))

                            privateCopy?.items.uris = claimSearch.items
                                .sorted(like: claimIds, keyPath: \.claimId, transform: \.self)
                                .compactMap(\.permanentUrl)
                                .compactMap { LbryUri.tryParse(url: $0, requireProto: true) }
                        }
                    }
                } catch {
                    Helper.showError(
                        message: "Error keeping private copy of playlist; the playlist was not deleted: \(error.localizedDescription)"
                    )
                    return
                }

                if collection.isPublished {
                    do {
                        _ = try await BackendMethods.streamAbandon.call(params: .init(
                            claimId: collection.collectionId,
                            blocking: true
                        ))

                        try await collectionListAll()
                    } catch {
                        Helper.showError(message: "Error removing uploaded playlist: \(error.localizedDescription)")
                        return
                    }
                }

                await Wallet.withSyncedPrefs { prefs in
                    if let privateCopy {
                        prefs.addOrSetUnpublishedCollection(collection: privateCopy)
                    }

                    switch collection.origin {
                    case .saved:
                        prefs.removeSavedCollection(collection: collection)
                    case .unpublished:
                        prefs.removeUnpublishedCollection(collection: collection)
                    case .edited:
                        prefs.removeEditedCollection(collection: collection)
                    default:
                        break
                    }
                }

                Helper.showMessage(message: "Playlist removed")
            }
        }

        func collectionListAll() async throws {
            publishedCollections = try await Self.collectionListAll()
        }

        static func collectionListAll() async throws -> SharedPreference.CollectionGroup {
            var collections = SharedPreference.CollectionGroup()

            // Limit in case of failure to break
            for page in 1 ... 999 {
                let published = try await BackendMethods.collectionList.call(params: .init(
                    page: page,
                    pageSize: Self.pageSize
                ))

                collections.merge(published.items.compactMap {
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

            return collections
        }

        private func collectionClaimSearch(_ claimIds: [String]) async throws {
            savedCollections.removeAll(keepingCapacity: true)

            guard claimIds.count > 0 else {
                return
            }

            // Limit in case of failure to break
            for page in 1 ... 999 {
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
