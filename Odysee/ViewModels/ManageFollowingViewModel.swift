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

        private var toSetNotificationsDisabled = [Claim: Wallet.NotificationsDisabled]()
        private var toRemove: [Claim] = []

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
            return toSetNotificationsDisabled[
                follow,
                default: Wallet.isNotificationsDisabled(claim: follow, for: walletFollowing)
            ]
        }

        func markToggleNotificationsDisabled(follow: Claim) -> Wallet.NotificationsDisabled {
            let new = !isNotificationsDisabled(follow: follow)
            toSetNotificationsDisabled[follow] = new
            return new
        }

        func markRemove(follow: Claim) {
            toRemove.append(follow)
        }

        // TODO: Consider calling this with debounce (instead of when leaving the screen)
        // If so, make sure to snapshot toSetNotificationDisabled and toRemove, then immediately clear,
        //   so new changes don't affect, and build up for next call
        func updateMarkedNotificationsDisabled_and_removeMarked() async throws {
            inProgress = true
            defer {
                inProgress = false
            }

            // Only update follows that still exist (not removed)
            // Need to update all remaining, even if locally notificationsDisabled is same as toUpdate
            //   because it may have changed remotely (will be handled in pull/push, but unknown for API call)
            let toUpdate = toSetNotificationsDisabled.filter { claim, _ in
                !toRemove.contains(where: { claim == $0 })
            }

            try await withThrowingTaskGroup { taskGroup in
                for (claim, notificationsDisabled) in toUpdate {
                    guard let claimId = claim.claimId,
                          let channelName = claim.name
                    else {
                        throw GenericError("couldn't get claim info")
                    }

                    taskGroup.addTask {
                        _ = try await AccountMethods.subscriptionNew.call(params: .init(
                            claimId: claimId,
                            channelName: channelName,
                            notificationsDisabled: notificationsDisabled
                        ))
                    }
                }

                for claim in toRemove {
                    guard let claimId = claim.claimId else {
                        throw GenericError("couldn't get claim id")
                    }

                    taskGroup.addTask {
                        _ = try await AccountMethods.subscriptionDelete.call(params: .init(claimId: claimId))
                    }
                }

                // Make task group throwing
                try await taskGroup.waitForAll()
            }

            await Wallet.shared.updateNotificationsDisabledAll_and_removeFollowingAll(
                toUpdate: toUpdate, toRemove: toRemove
            )
            await Wallet.shared.queuePushSync()

            toSetNotificationsDisabled.removeAll()
            toRemove.removeAll()
        }
    }
}
