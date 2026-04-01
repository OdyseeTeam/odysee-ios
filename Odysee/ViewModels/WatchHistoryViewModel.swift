//
//  WatchHistoryViewModel.swift
//  Odysee
//
//  Created by Keith Toh on 18/03/2026.
//

import Foundation

extension WatchHistoryScreen {
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
                let viewHistory = try await AccountMethods.viewHistory.call(params: .init(
                    page: page,
                    pageSize: Self.pageSize
                ))

                let urls = viewHistory.items.compactMap {
                    try? LbryUri.normalize(url: "lbry://\($0.claimName):\($0.claimId)")
                }

                let lastPositionClaimIds = Dictionary(
                    viewHistory.items.map { ($0.claimId, $0.lastPosition) },
                    uniquingKeysWith: { _, last in last }
                )

                let resolve = try await BackendMethods.resolve.call(params: .init(urls: urls))
                claims.append(contentsOf:
                    resolve.claims.values.sorted(
                        like: viewHistory.items.map(\.claimId),
                        keyPath: \.claimId,
                        transform: \.self
                    ).map { claim in
                        var claim = claim

                        if let claimId = claim.claimId,
                           let lastPosition = lastPositionClaimIds[claimId]
                        {
                            claim.lastPosition = lastPosition
                        }

                        return claim
                    }
                )

                isLastPage = viewHistory.isLastPage

                page += 1
            } catch {
                Helper.showError(error: error)
            }
        }

        func delete(firstFromOffset offsets: IndexSet) async {
            guard let offset = offsets.first,
                  claims.count > offset,
                  let claimId = claims[offset].claimId
            else {
                Helper.showError(message: "claim has nil claimId")
                return
            }

            inProgress = true
            defer {
                inProgress = false
            }

            do {
                _ = try await AccountMethods.viewHistoryDelete.call(params: .init(
                    claimId: claimId
                ))

                claims.remove(atOffsets: IndexSet(integer: offset))
            } catch {
                Helper.showError(error: error)
            }
        }

        func clearHistory() async {
            inProgress = true
            defer {
                inProgress = false
            }

            do {
                _ = try await AccountMethods.viewHistoryDeleteAll.call(params: .init())

                await refresh()
            } catch {
                Helper.showError(error: error)
            }
        }
    }
}
