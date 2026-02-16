//
//  ManageFollowingScreen.swift
//  Odysee
//
//  Created by Keith Toh on 07/02/2026.
//

import CachedAsyncImage
import SwiftUI

extension ManageFollowingScreen {
    struct Screen: View {
        @ObservedObject var model: ViewModel
        var openChannel: (Claim) -> Void

        @State private var search: String = ""

        private var filteredFollowing: [Claim]? {
            model.search(search)
        }

        var body: some View {
            ZStack {
                if let following = model.following, let filteredFollowing {
                    if following.isEmpty {
                        Text("No followed channels.")
                    } else {
                        List(filteredFollowing) { follow in
                            // UIKit action, but disclosure using empty NavigationLink
                            Button {
                                openChannel(follow)
                            } label: {
                                NavigationLink {
                                    EmptyView()
                                } label: {
                                    ChannelListItem(channel: follow)
                                }
                            }
                            .tint(Color(UIColor.label))
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task {
                                        let disabled = await model.toggleNotificationsDisabled(follow: follow)

                                        if disabled {
                                            Helper.showMessage(
                                                message: "Notifications turned off for \(follow.name ?? "")"
                                            )
                                        } else {
                                            Helper.showMessage(
                                                message: "Notifications turned on for \(follow.name ?? "")"
                                            )
                                        }
                                    }
                                } label: {
                                    if model.isNotificationsDisabled(follow: follow) {
                                        Label("Enable Notifications", systemImage: "bell.fill")
                                    } else {
                                        Label("Disable Notifications", systemImage: "bell.slash")
                                    }
                                }
                                .tint(.blue)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task {
                                        await model.remove(follow: follow)
                                    }
                                } label: {
                                    Label("Unfollow", systemImage: "heart.slash")
                                }
                            }
                        }
                        .apply {
                            if #available(iOS 16, *) {
                                $0.scrollContentBackground(.hidden)
                            } else {
                                $0
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .controlSize(.large)
                }

                ProgressView()
                    .controlSize(.large)
                    .apply {
                        if model.inProgress {
                            $0
                        } else {
                            $0.hidden()
                        }
                    }
            }
            .refreshable {
                do {
                    try await model.refresh()
                } catch {
                    Helper.showError(error: error)
                }
            }
            .searchable(text: $search)
            .navigationTitle("Followed Channels")
        }
    }
}

struct ManageFollowingScreen: View {
    @ObservedObject var navigator: Navigator

    class Navigator: ObservableObject {
        @Published var active: Bool = false

        var hide: () -> Void

        init(hide: @escaping () -> Void) {
            self.hide = hide
        }

        func show() {
            active = true
        }
    }

    @ObservedObject var model: ViewModel
    var openChannel: (Claim) -> Void

    var body: some View {
        NavigationView {
            NavigationLink(isActive: $navigator.active) {
                Screen(model: model, openChannel: openChannel)
            } label: {
                EmptyView()
            }
            .hidden()
            .onChange(of: navigator.active) {
                if !$0 {
                    navigator.hide()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    ManageFollowingScreen.Screen(
        model: .init(
            following: [
                .init(
                    claimId: "all-info-present",
                    name: "@Odysee",
                    value: .init(
                        title: "Odysee",
                        thumbnail: .init(url: "https://thumbs.odycdn.com/5a920753363de87d6f1f4b0d90b44706.webp"),
                    ),
                ),
            ]
        ),
        openChannel: { _ in }
    )
}
