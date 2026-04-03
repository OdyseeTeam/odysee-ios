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

        private var toRemove: [Claim] = []

        init(following: [Claim]? = nil) {
            self.following = following
        }

        func update(following: [Claim], walletFollowing: Wallet.Following) {
            inProgress = true
            defer {
                inProgress = false
            }

            // FIXME: call removes

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

        // FIXME: Got "hash mismatch" error when (1) web unfollow (2) iOS remove (3) iOS back button [save]

        // FIXME: batch, if added to todo twice then remove (since it's a toggle)?
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

        func markRemove(follow: Claim) {
            toRemove.append(follow)
        }

        func removeMarked() async {
            await Wallet.shared.removeFollowingAll(claims: toRemove)
            await Wallet.shared.queuePushSync()
            toRemove.removeAll()
        }
    }
}
