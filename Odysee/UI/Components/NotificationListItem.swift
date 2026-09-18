//
//  NotificationListItem.swift
//  Odysee
//
//  Created by Keith on 15/09/2026.
//

import CachedAsyncImage
import Network
import SwiftUI
import WrappingHStack

struct NotificationListItem: View {
    var notification: Notification

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var unlimitedLines: Bool = false

    var body: some View {
        Button {
            Task {
                do {
                    try await handleClick()
                } catch {
                    Helper.showError(error: error)
                }
            }
        } label: {
            HStack {
                switch notification.icon {
                case let .system(name):
                    Image(systemName: name)
                        .notificationIconStyle()
                        .foregroundStyle(
                            name == Icons.notificationSubscription ?
                                Icons.notificationSubscriptionColor :
                                .primary
                        )
                case let .asset(imageResource):
                    Image(imageResource)
                        .notificationIconStyle()
                case let .channel(url, name):
                    ChannelThumbnail(channel: (name: name, thumbnail: url))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if horizontalSizeClass == .compact {
                        title

                        text

                        activeAt
                    } else {
                        WrappingHStack(spacing: .dynamic(minSpacing: 0), lineSpacing: 8) {
                            title

                            activeAt
                        }

                        text
                    }
                }

                if !notification.isRead {
                    Spacer()

                    Circle()
                        .foregroundStyle(.accentColor)
                        .frame(width: 10, height: 10)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func handleClick() async throws {
        try await Account.shared.markNotificationReadIfNeeded(notification: notification)

        // FIXME: Other

        // FIXME: new_member needs special case: https://github.com/OdyseeTeam/odysee-frontend/blob/8f2001d4ee4fb6d80184baf62a58e3403f98861d/ui/component/notification/view.tsx#L109
    }

    private var title: some View {
        // FIXME: Accessibility
        Button {
            unlimitedLines.toggle()
        } label: {
            Text(notification.title ?? "")
                .lineLimit(unlimitedLines ? nil : 2)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var activeAt: some View {
        Text(Helper.formatDate(notification.activeAt))
            .lineLimit(1)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var text: some View {
        // FIXME: Accessibility
        Button {
            unlimitedLines.toggle()
        } label: {
            Text(notification.text ?? "")
                .lineLimit(unlimitedLines ? nil : 2)
        }
    }
}

extension Image {
    func notificationIconStyle() -> some View {
        resizable()
            .scaledToFill()
            .frame(width: 30, height: 30)
            .padding(5)
    }
}

extension Notification {
    enum NotificationIcon {
        case system(name: String)
        case asset(ImageResource)
        case channel(url: String, name: String)
    }

    var icon: NotificationIcon {
        func channel(for claimInfo: Notification.NotificationParameters.Dynamic.ClaimInfo) -> NotificationIcon {
            .channel(url: claimInfo.channelThumbnail, name: claimInfo.channelUrl)
        }

        switch notificationRule {
        case .creatorSubscriber:
            return .system(name: Icons.notificationSubscription)
        case .comment,
             .creatorComment:
            if case let .comment(comment) = notificationParameters?.dynamic {
                return .channel(url: comment.commentAuthorThumbnail, name: comment.commentAuthor)
            }
        case .commentReply:
            if case let .reply(reply) = notificationParameters?.dynamic {
                return .channel(url: reply.commentAuthorThumbnail, name: reply.replyAuthor)
            }
        case .newContent:
            if case let .subscription(claimInfo) = notificationParameters?.dynamic, let claimInfo {
                return channel(for: claimInfo)
            }
        case .newLivestream:
            if case let .livestream(claimInfo) = notificationParameters?.dynamic {
                return channel(for: claimInfo)
            }
        case .newMember:
            return .system(name: "paperplane") // FIXME: Membership is rocket
        case .weeklyWatchReminder,
             .dailyWatchAvailable,
             .dailyWatchRemind,
             .missedOut,
             .rewardsApprovalPrompt:
            return .asset(.creditsIcon)
        case .fiatTip:
            return .system(name: Icons.notificationFiatTip)
        case .other:
            // Fallthrough to default icon (missing/invalid dynamic will also use default)
            break
        }

        return .system(name: Icons.notification)
    }
}

#Preview {
    func notification(
        rule: Notification.NotificationRule,
        dynamic: Notification.NotificationParameters.Dynamic
    ) -> Notification {
        return .init(
            id: UInt64.random(in: 0 ... UInt64.max),
            notificationRule: rule,
            isRead: Bool.random(),
            isSeen: true,
            activeAt: Date.now,
            notificationParameters: .init(
                device: .init(
                    name: "abc",
                    title: "def",
                    text: rule.rawValue,
                    type: "jkl",
                    target: "lbry://mno"
                ),
                dynamic: dynamic
            )
        )
    }

    return (List {
        NotificationListItem(notification: notification(
            rule: .creatorSubscriber,
            dynamic: .unknown([:])
        ))

        NotificationListItem(notification: notification(
            rule: .comment,
            dynamic: .comment(.init(
                hash: "",
                parentId: "",
                commentAuthor: "lbry://@Odysee#8",
                claimTitle: "",
                comment: "",
                amount: "",
                commentAuthorThumbnail: ""
            ))
        ))

        NotificationListItem(notification: notification(
            rule: .comment,
            dynamic: .comment(.init(
                hash: "",
                parentId: "",
                commentAuthor: "lbry://@Odysee#8",
                claimTitle: "",
                comment: "",
                amount: "",
                commentAuthorThumbnail: "https://thumbs.odycdn.com/5a920753363de87d6f1f4b0d90b44706.webp"
            ))
        ))

        NotificationListItem(notification: notification(
            rule: .commentReply,
            dynamic: .reply(.init(
                hash: "",
                parentId: "",
                replyAuthor: "lbry://@Odysee#8",
                claimTitle: "",
                parentComment: "",
                comment: "",
                amount: "",
                commentAuthorThumbnail: "https://thumbs.odycdn.com/5a920753363de87d6f1f4b0d90b44706.webp"
            ))
        ))

        NotificationListItem(notification: notification(
            rule: .newContent,
            dynamic: .subscription(nil)
        ))

        NotificationListItem(notification: notification(
            rule: .newContent,
            dynamic: .subscription(.init(
                claimTitle: "",
                channelUrl: "lbry://@Odysee#8",
                channelThumbnail: "",
                claimThumbnail: "",
                claimName: ""
            ))
        ))

        NotificationListItem(notification: notification(
            rule: .newLivestream,
            dynamic: .livestream(.init(
                claimTitle: "",
                channelUrl: "lbry://@Odysee#8",
                channelThumbnail: "https://thumbs.odycdn.com/5a920753363de87d6f1f4b0d90b44706.webp",
                claimThumbnail: "",
                claimName: ""
            ))
        ))

        NotificationListItem(notification: notification(
            rule: .newMember,
            dynamic: .unknown([:])
        ))

        NotificationListItem(notification: notification(
            rule: .weeklyWatchReminder,
            dynamic: .unknown([:])
        ))

        NotificationListItem(notification: notification(
            rule: .fiatTip,
            dynamic: .unknown([:])
        ))

        NotificationListItem(notification: notification(
            rule: .other,
            dynamic: .reward(())
        ))
    })
}
