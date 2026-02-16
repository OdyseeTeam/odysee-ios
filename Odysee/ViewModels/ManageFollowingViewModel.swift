//
//  ManageFollowingViewModel.swift
//  Odysee
//
//  Created by Keith Toh on 13/02/2026.
//

import Foundation

extension ManageFollowingScreen {
    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var inProgress = false

        @Published private(set) var following: [Claim]?
        // Local copy used for checking notificationsDisabled
        private var walletFollowing: Wallet.Following?

        init(following: [Claim]? = nil) {
            self.following = following
        }

        func update(following: [Claim], walletFollowing: Wallet.Following) {
            inProgress = true
            defer {
                inProgress = false
            }

            self.following = following
            self.walletFollowing = walletFollowing
        }

        func refresh() async throws {
            try await Wallet.shared.pullSync()
        }

        func search(_ search: String) -> [Claim]? {
            if search.isBlank {
                following
            } else {
                following?.filter {
                    ($0.titleOrName ?? "").localizedStandardContains(search)
                }
            }
        }

        func isNotificationsDisabled(follow: Claim) -> Wallet.NotificationsDisabled {
            Wallet.isNotificationsDisabled(claim: follow, for: walletFollowing)
        }

        func toggleNotificationsDisabled(follow: Claim) async -> Wallet.NotificationsDisabled {
            inProgress = true
            defer {
                inProgress = false
            }

            let new = !(await Wallet.shared.isNotificationsDisabled(claim: follow))
            await Wallet.shared.addOrSetFollowing(claim: follow, notificationsDisabled: new)
            await Wallet.shared.queuePushSync()
            return new
        }

        func remove(follow: Claim) async {
            inProgress = true
            defer {
                inProgress = false
            }

            await Wallet.shared.removeFollowing(claim: follow)
            await Wallet.shared.queuePushSync()
        }
    }
}
