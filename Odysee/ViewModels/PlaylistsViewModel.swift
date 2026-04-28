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
        private var page = 1

        @Published private(set) var inProgress = false
        @Published private(set) var refreshing = false

        @Published private(set) var unpublishedCollections = [SharedPreference.Collection]()
        @Published private(set) var publishedCollections = [SharedPreference.Collection]()

        init() {
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
        }

        @Sendable func refresh() async {
            refreshing = true
            defer {
                refreshing = false
            }

            publishedCollections.removeAll(keepingCapacity: true)

            do {
                try await collectionListAll()
            } catch {
                Helper.showError(error: error)
            }
        }

        private func collectionListAll() async throws {
            // Limit in case of failure to break
            for _ in 0 ... 999 {
                let published = try await BackendMethods.collectionList.call(params: .init(
                    resolve: true,
                    page: page,
                    pageSize: Self.pageSize
                ))

                publishedCollections.append(contentsOf: published.items.compactMap(\.asCollection))

                if published.isLastPage {
                    break
                }
                page += 1
            }
        }
    }
}
