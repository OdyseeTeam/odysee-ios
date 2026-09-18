//
//  NotificationsScreen.swift
//  Odysee
//
//  Created by Keith on 15/09/2026.
//

import SwiftUI

// FIXME: Auto mark as seen
struct NotificationsScreen: View {
    @ObservedObject private var account = Account.shared

    @State private var refreshing = false

    var body: some View {
        ZStack {
            NavigationView {
                List {
                    Group {
                        ForEach(account.notifications) { notification in
                            NotificationListItem(notification: notification)
                        }
                        .onDelete(perform: account.deleteNotifications)
                        .deleteDisabled(account.inProgress)

                        MiniPlayerAvoiding()
                    }
                    .listRowSeparator(.hidden)
                }
                .refreshable {
                    refreshing = true
                    defer {
                        refreshing = false
                    }

                    await account.reloadNotifications()
                }
                .listStyle(.plain)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Mark all as read") {
                            Task {
                                await account.markAllNotificationsRead()
                            }
                        }
                        .disabled(account.notifications.allSatisfy(\.isRead))
                    }
                }
                .task(account.markAllNotificationsSeen)
            }
            .navigationViewStyle(.stack)

            ProgressView()
                .controlSize(.large)
                .apply {
                    if !refreshing && account.inProgress {
                        $0
                    } else {
                        $0.hidden()
                    }
                }
        }
    }
}

#Preview {
    NotificationsScreen()
}
