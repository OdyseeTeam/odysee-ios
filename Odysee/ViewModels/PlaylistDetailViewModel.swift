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

        init(claims: [Claim] = []) {
            self.claims = claims
        }

        func loadClaims(collection: SharedPreference.Collection) async throws {
            guard let playlistClaims = collection.asClaim.value?.claims,
                  playlistClaims.count > 0
            else {
                return
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

        func saveChanges(collection: SharedPreference.Collection) async {
            var collection = collection
            collection.items.uris = claims.compactMap {
                guard let url = $0.permanentUrl else {
                    return nil
                }

                return LbryUri.tryParse(url: url, requireProto: true)
            }

            switch collection.origin {
            case .builtin:
                await Wallet.shared.addOrSetBuiltin(collection: collection)
            case .edited,
                 .claim:
                await Wallet.shared.addOrSetEdited(collection: collection)
            case .saved:
                break // FIXME: Ensure this path never gets hit
            case .unpublished:
                await Wallet.shared.addOrSetUnpublished(collection: collection)
            case .none:
                break
            }

            await Wallet.shared.queuePushSync()
        }
    }
}
