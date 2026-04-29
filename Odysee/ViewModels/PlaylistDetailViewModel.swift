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

                claims.append(contentsOf: claimSearch.items)

                if claimSearch.isLastPage {
                    break
                }
            }
        }

        func move(from source: IndexSet, to destination: Int) {
            // FIXME: Need sync behaviour like manage following
            // "Easier" since this is all SwiftUI so just add isActive to PlaylistListItem link?
            claims.move(fromOffsets: source, toOffset: destination)
        }
    }
}
