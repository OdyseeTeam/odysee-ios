//
//  PlaylistDetailViewModel.swift
//  Odysee
//
//  Created by Keith Toh on 29/04/2026.
//

import Foundation

extension PlaylistDetailScreen {
    @MainActor
    class ViewModel: ObservableObject {
        static let pageSize = 50

        @Published private(set) var inProgress = false
        @Published private(set) var refreshing: Bool = false

        @Published private(set) var claims: [Claim]

        @Published private(set) var walletSavedCollectionIds: [String] = []

        init(claims: [Claim] = []) {
            self.claims = claims

            Task<Void, Never> {
                walletSavedCollectionIds = await Wallet.shared.savedCollectionIds

                for await newSavedCollectionIds in await Wallet.shared.$savedCollectionIds {
                    walletSavedCollectionIds = newSavedCollectionIds
                }
            }
        }

        func loadClaims(collection: SharedPreference.Collection) async throws {
            guard let playlistClaims = collection.asClaim.value?.claims,
                  playlistClaims.count > 0
            else {
                return
            }

            inProgress = true
            defer {
                inProgress = false
            }

            claims.removeAll(keepingCapacity: true)

            // Limit in case of failure to break
            for page in 0 ... 999 {
                let claimSearch = try await BackendMethods.claimSearch.call(params: .init(
                    page: page,
                    pageSize: Self.pageSize,
                    claimIds: playlistClaims,
                ))

                claims.append(contentsOf: claimSearch.items.sorted(
                    like: playlistClaims, keyPath: \.claimId, transform: \.self
                ))

                if claimSearch.isLastPage {
                    break
                }
            }
        }

        func move(from source: IndexSet, to destination: Int) {
            claims.move(fromOffsets: source, toOffset: destination)
        }

        func delete(at offsets: IndexSet) {
            claims.remove(atOffsets: offsets)
        }

        func copy(collection: SharedPreference.Collection, title: String) async {
            let now = Int(Date().timeIntervalSince1970)

            await Wallet.shared.addOrSetUnpublished(collection: .init(
                id: UUID().uuidString,
                items: .init(uris: claims.compactMap {
                    guard let url = $0.permanentUrl else {
                        return nil
                    }

                    return LbryUri.tryParse(url: url, requireProto: true)
                }),
                name: title,
                title: title,
                description: collection.description,
                tags: collection.tags,
                thumbnail: collection.thumbnail,
                type: .playlist,
                createdAt: now,
                updatedAt: now,
                itemCount: collection.itemCount,
                sourceId: collection.originalClaim?.claimId,

                origin: .unpublished
            ))

            await Wallet.shared.queuePushSync()
        }

        func saveChanges(collection: SharedPreference.Collection) async -> SharedPreference.Collection {
            inProgress = true
            defer {
                inProgress = false
            }

            var collection = collection
            collection.items.uris = claims.compactMap {
                guard let url = $0.permanentUrl else {
                    return nil
                }

                return LbryUri.tryParse(url: url, requireProto: true)
            }

            collection = await Self.saveCollection(collection)

            await Wallet.shared.queuePushSync()

            return collection
        }

        @discardableResult nonisolated
        static func saveCollection(_ collection: SharedPreference.Collection) async -> SharedPreference.Collection {
            return switch collection.origin {
            case .builtin:
                await Wallet.shared.setBuiltin(collection: collection)
            case .edited,
                 .published:
                await Wallet.shared.addOrSetEdited(collection: collection)
            case .unpublished:
                await Wallet.shared.addOrSetUnpublished(collection: collection)
            case .saved,
                 .claim,
                 .none:
                collection
            }
        }

        func publish(collection: SharedPreference.Collection) async {
            do {
                if collection.origin == .unpublished {
                    _ = try await BackendMethods.collectionCreate.call(params: .init(
                        name: collection.name,
                        claims: collection.items.uris.compactMap(\.streamClaimId),
                        title: collection.title,
                        description: collection.description,
                        tags: collection.tags,
                        thumbnailUrl: collection.thumbnail?.url?.absoluteString,
                        channelId: collection.publishChannel?.claimId
                    ))

                    await Wallet.shared.removeUnpublished(collection: collection)
                } else {
                    _ = try await BackendMethods.collectionUpdate.call(params: .init(
                        claimId: collection.collectionId,
                        claims: collection.items.uris.compactMap(\.streamClaimId),
                        title: collection.title,
                        description: collection.description,
                        tags: collection.tags,
                        thumbnailUrl: collection.thumbnail?.url?.absoluteString,
                        channelId: collection.publishChannel?.claimId
                    ))

                    await Wallet.shared.removeEdited(collection: collection)
                }

                await Wallet.shared.queuePushSync()
            } catch {
                Helper.showError(message: "Error publishing playlist: \(error.localizedDescription)")
            }
        }
    }
}
