//
//  PublishesViewModel.swift
//  Odysee
//
//  Created by Keith Toh on 31/03/2026.
//

import Foundation

extension PublishesScreen {
    @MainActor
    class ViewModel: ObservableObject {
        static let pageSize = 20
        private var page = 1

        @Published private(set) var inProgress = false
        @Published private(set) var refreshing = false

        @Published private(set) var isLastPage = false
        @Published private(set) var claims: [Claim]

        init(claims: [Claim] = []) {
            self.claims = claims
        }

        @Sendable func refresh() async {
            refreshing = true
            defer {
                refreshing = false
            }

            page = 1
            claims.removeAll(keepingCapacity: true)
            await loadPage(indicateProgress: false)
        }

        @Sendable func loadPage(indicateProgress: Bool = true) async {
            if indicateProgress {
                inProgress = true
            }
            defer {
                inProgress = false
            }

            do {
                let uploads = try await BackendMethods.claimList.call(params: .init(
                    claimType: [.stream],
                    page: page,
                    pageSize: Self.pageSize,
                    resolve: true
                ))

                claims.append(contentsOf: uploads.items)
                isLastPage = uploads.isLastPage

                page += 1
            } catch {
                Helper.showError(error: error)
            }
        }

        func delete(claim: Claim) async {
            guard let claimId = claim.claimId else {
                Helper.showError(message: "claim has nil claimId")
                return
            }

            inProgress = true
            defer {
                inProgress = false
            }

            do {
                _ = try await BackendMethods.streamAbandon.call(params: .init(
                    claimId: claimId, blocking: true
                ))

                claims.removeAll(where: { $0.claimId == claim.claimId })
            } catch {
                Helper.showError(error: error)
            }
        }
    }
}
