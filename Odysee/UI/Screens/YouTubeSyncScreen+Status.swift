//
//  YouTubeSyncScreen+Status.swift
//  Odysee
//
//  Created by Keith Toh on 24/02/2026.
//

import SwiftUI

extension YouTubeSyncScreen {
    struct Status: View {
        @ObservedObject var model: YouTubeSyncScreen.ViewModel

        @ScaledMetric private var scale: CGFloat = 1

        var body: some View {
            VStack(alignment: .leading) {
                if let channels = model.channels {
                    Group {
                        if ViewModel.isNotElligible(channels: channels) {
                            Text("Process complete")
                        } else if ViewModel.isYoutubeTransferComplete(channels: channels) {
                            Text("Transfer complete")
                        } else if channels.count > 1 {
                            Text("Your YouTube channels")
                        } else {
                            Text("Your YouTube channel")
                        }
                    }
                    .font(.title)

                    Group {
                        if ViewModel.hasPendingTransfers(channels: channels) {
                            Text("Your videos are currently being transferred. There is nothing else for you to do.")
                        } else if ViewModel.isNotElligible(channels: channels) {
                            Text(
                                "Email help@odysee.com if you think there has been a mistake. Make sure your channel qualifies [here](https://help.odysee.tv/category-syncprogram/)."
                            )
                        } else if ViewModel.transferEnabled(channels: channels) {
                            Text("Your videos are ready to be transferred.")
                        } else if ViewModel.isYoutubeTransferComplete(channels: channels) {
                            Text("View your channel or choose a new channel to sync.")
                        } else {
                            Text("Please check back later, this may take a few hours.")
                        }
                    }
                    .font(.title3)

                    List(channels) { channel in
                        Group {
                            if !channel.channelClaimId.isBlank {
                                // UIKit action, but disclosure using empty NavigationLink
                                Button {} label: {
                                    NavigationLink {
                                        EmptyView()
                                    } label: {
                                        let message = {
                                            if channel.transferable {
                                                return __("Ready to transfer")
                                            }

                                            switch channel.transferState {
                                            case .notTransferred:
                                                return channel.syncStatus.rawValue.capitalized
                                            case .pendingTransfer:
                                                return __("Transfer in progress")
                                            case .completedTransfer:
                                                return __("Completed transfer")
                                            default:
                                                return __("Unknown transfer status")
                                            }
                                        }()

                                        ChannelListItem(
                                            channel: .uri(
                                                name: channel.lbryChannelName,
                                                claimId: channel.channelClaimId
                                            ),
                                            otherText: message
                                        )
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    if channel.syncStatus == .abandoned && channel.reviewed {
                                        Text(
                                            "\(channel.lbryChannelName) is not eligible to be synced, reach out to hello@odysee.com for access to the self sync tool."
                                        )
                                    } else {
                                        Text(Image(systemName: "checkmark.circle"))
                                            .accessibilityLabel("Completed")
                                            + Text(" Claim your handle \(channel.lbryChannelName)")

                                        Text(Image(systemName: "checkmark.circle"))
                                            .accessibilityLabel("Completed")
                                            + Text(" Agree to sync")

                                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                                            if !channel.reviewed {
                                                Text(Image(systemName: "circle"))
                                                    .accessibilityHidden(true)

                                                Text(" ")
                                                Text("Automated sync status is still under review")
                                            } else if channel.vip {
                                                let isWaitingForSync = [
                                                    .queued,
                                                    .pending,
                                                    .pendingEmail,
                                                    .pendingUpgrade,
                                                    .syncing
                                                ].contains(channel.syncStatus)

                                                if isWaitingForSync {
                                                    ProgressView()
                                                        .accessibilityHidden(true)
                                                } else {
                                                    Image(systemName: "checkmark.circle")
                                                        .accessibilityLabel("Completed")
                                                }

                                                Text(" ")
                                                Text("Wait for your videos to be synced")
                                            } else {
                                                Text(Image(systemName: "circle"))
                                                    .accessibilityHidden(true)

                                                Text(" ")
                                                Text(
                                                    "Wait for sync to start or reach out to hello@odysee.com to try our self sync tool"
                                                )
                                            }
                                        }

                                        Text(
                                            "Syncing ^[\(channel.totalVideos) video](inflect:true) from your channel with ^[\(channel.totalSubs) subscription](inflect: true)."
                                        )
                                        .font(.caption)

                                        Text(
                                            "* Not all content may be processed, there are limitations based on both Youtube and Odysee activity. Click Learn More at the bottom to see the latest requirements and limits. We have a self sync tool to process the rest, reach out to hello@odysee.com to get access."
                                        )
                                        .font(.caption)

                                        HStack(spacing: 0) {
                                            Text(Image(systemName: "circle"))
                                                .apply {
                                                    if !ViewModel.isYoutubeTransferComplete(channels: channels) {
                                                        $0
                                                            .accessibilityLabel(
                                                                "Use the button below to claim your channel"
                                                            )
                                                    } else {
                                                        $0.accessibilityLabel("Claim your channel later")
                                                    }
                                                }

                                            Text(" Claim your channel")
                                                .accessibilityHidden(true)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .apply {
                                    if !channel.channelClaimId.isBlank {
                                        $0.fill(Color.accentColor.opacity(0.3))
                                    } else {
                                        $0.stroke(Color.accentColor)
                                    }
                                }
                        )
                        .listRowSeparator(.hidden)
                        .accessibilityElement(children: .combine)
                    }
                    .listStyle(.plain)
                    .frame(minHeight: 100 * scale)
                    .refreshable(action: model.refreshStatus)

                    if let (total: total, complete: complete) = model.youtubeTransferStatus {
                        // NOTE(discuss): Inflect singular?
                        Text("\(complete) / \(total) videos transferred")
                    }

                    if !ViewModel.isYoutubeTransferComplete(channels: channels) {
                        Button {
                            Task<Void, Never> {
                                do {
                                    try await model.claimChannels()
                                } catch {
                                    Helper.showError(error: error)
                                }
                            }
                        } label: {
                            if channels.count > 1 {
                                Text("Claim channels")
                            } else {
                                Text("Claim channel")
                            }
                        }
                        .padding(.bottom)
                        .disabled(!ViewModel.transferEnabled(channels: channels))
                    }

                    Button("Add Another Channel") {
                        // TODO(when SwiftUI navigation): Push destination
                        model.showStatus = false
                    }

                    Divider()

                    let pending = if model.inProgress {
                        __(" You will not be able to edit the channel or content until the transfer process completes.")
                    } else {
                        ""
                    }
                    if channels.count > 1 {
                        Text(
                            "You will be able to claim your channels once they finish syncing.\(pending) [Learn More](https://help.odysee.tv/category-syncprogram/)"
                        )
                    } else {
                        Text(
                            "You will be able to claim your channel once it has finished syncing.\(pending) [Learn More](https://help.odysee.tv/category-syncprogram/)"
                        )
                    }
                } else {
                    Button("Reload") {
                        Task<Void, Never> {
                            await model.refreshStatus(indicateProgress: true)
                        }
                    }
                    .padding(.top)
                }
            }
            .padding()
        }
    }
}

#Preview {
    let notEligible: AccountYoutubeChannel = .init(
        ytChannelId: "NOTELIGIBLE",
        ytChannelName: "TestChannel",
        lbryChannelName: "@TestChannel",
        channelClaimId: "",
        syncStatus: .abandoned,
        statusToken: "1234ABCD",
        transferable: false,
        transferState: .completedTransfer,
        shouldSync: false,
        vip: false,
        reviewed: true,
        totalSubs: 0,
        totalVideos: 0,
        publicKey: ""
    )
    let synced: AccountYoutubeChannel = .init(
        ytChannelId: "SYNCED",
        ytChannelName: "TestChannel",
        lbryChannelName: "@TestChannel",
        channelClaimId: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        syncStatus: .synced,
        statusToken: "1234ABCD",
        transferable: false,
        transferState: .completedTransfer,
        shouldSync: true,
        vip: true,
        reviewed: true,
        totalSubs: 999,
        totalVideos: 1,
        publicKey: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    )

    YouTubeSyncScreen.Status(model: .init(
        channels: [
            notEligible,
            synced,
        ]
    ))
}
