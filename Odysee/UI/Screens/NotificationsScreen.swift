//
//  NotificationsScreen.swift
//  Odysee
//
//  Created by Keith on 15/09/2026.
//

import SwiftUI

struct NotificationsScreen: View {
    @ObservedObject private var account = Account.shared
    var notifications: [Notification] {
        account.notifications
    }

    var body: some View {
        List {
            Group {
                ForEach(notifications) { notification in
                    NotificationListItem(notification: notification)
                }

                MiniPlayerAvoiding()
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}

#Preview {
    NotificationsScreen()
}
