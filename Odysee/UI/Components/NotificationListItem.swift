//
//  NotificationListItem.swift
//  Odysee
//
//  Created by Keith on 15/09/2026.
//

import CachedAsyncImage
import SwiftUI
import WrappingHStack

struct NotificationListItem: View {
    var notification: Notification

    var body: some View {
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
            case let .url(url):
                // FIXME: Match/use ChannelThumbnail
                CachedAsyncImage(url: URL(string: url)) { phase in
                    if let image = phase.image {
                        image
                            .notificationIconStyle()
                    } else if phase.error != nil {
                        Color.clear
                    } else {
                        ProgressView()
                    }
                }
            }

            VStack(alignment: .leading) {
                WrappingHStack(spacing: .dynamic(minSpacing: 0), lineSpacing: 8) {
                    Text(notification.title ?? "")

                    // FIXME: Use helper
                    Text(notification.activeAt.formatted(.relative(presentation: .numeric)))
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(notification.text ?? "")
                    .lineLimit(2)
            }
        }
    }
}

extension Image {
    func notificationIconStyle() -> some View {
        resizable()
            .scaledToFill()
            .frame(width: 30, height: 30)
            .padding(10)
    }
}

extension Notification {
    enum NotificationIcon {
        case system(name: String)
        case asset(ImageResource)
        case url(String)
    }

    var icon: NotificationIcon {
        switch notificationRule {
        case .creatorSubscriber:
            return .system(name: Icons.notificationSubscription)
        case .comment,
             .creatorComment,
             .commentReply:
            if case let .comment(comment) = notificationParameters?.dynamic {
                return .url(comment.commentAuthorThumbnail)
            }
        case .newContent:
            if case let .subscription(claimInfo) = notificationParameters?.dynamic, let claimInfo {
                return .url(claimInfo.channelThumbnail)
            }
        case .newLivestream:
            if case let .livestream(claimInfo) = notificationParameters?.dynamic {
                return .url(claimInfo.channelThumbnail)
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
    NotificationListItem(notification: .init(
        id: 0,
        notificationRule: .other,
        isAppReadable: true,
        isRead: false,
        isSeen: false,
        activeAt: Date.now,
        notificationParameters: .init(
            device: .init(
                name: "abc",
                title: "def",
                text: "ghi",
                type: "jkl",
                target: "lbry://mno"
            ),
            dynamic: .reward(())
        )
    ))
}
