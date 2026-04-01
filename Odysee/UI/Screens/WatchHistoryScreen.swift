//
//  WatchHistoryScreen.swift
//  Odysee
//
//  Created by Keith Toh on 18/03/2026.
//

import SwiftUI

struct WatchHistoryScreen: View {
    @ObservedObject var model: ViewModel

    @State private var showingConfirmClear = false

    var body: some View {
        GeometryReader { metrics in
            ZStack {
                List {
                    Group {
                        if !model.refreshing {
                            if model.claims.isEmpty {
                                Image("spaceman_sad")
                                    .resizable()
                                    .scaledToFit()
                                    // Image is roughly a square
                                    .frame(
                                        maxWidth: .infinity,
                                        maxHeight: min(metrics.size.height / 2, metrics.size.width / 2),
                                        alignment: .center
                                    )
                                    .accessibilityHidden(true)

                                Text("Nothing here")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                Button("Clear History", role: .destructive) {
                                    showingConfirmClear = true
                                }
                                .padding(.horizontal)
                                .disabled(model.inProgress)
                                .confirmationDialog(
                                    "Watch history will be cleared from this device and your synced account.",
                                    isPresented: $showingConfirmClear,
                                    titleVisibility: .visible
                                ) {
                                    Button("Clear History", role: .destructive) {
                                        Task<Void, Never> {
                                            await model.clearHistory()
                                        }
                                    }
                                }
                            }
                        }

                        ForEach(model.claims) { claim in
                            Button {
                                let vc = AppDelegate.shared.mainViewController?.storyboard?
                                    .instantiateViewController(identifier: "file_view_vc") as! FileViewController
                                vc.claim = claim

                                AppDelegate.shared.mainNavigationController?.view.layer.add(
                                    Helper.buildFileViewTransition(),
                                    forKey: kCATransition
                                )
                                AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: false)
                            } label: {
                                ClaimListItem(claim: claim)
                            }
                        }
                        .onDelete { deleteOffsets in
                            Task<Void, Never> {
                                await model.delete(firstFromOffset: deleteOffsets)
                            }
                        }

                        if model.inProgress || model.isLastPage {
                            Color.clear
                        } else {
                            Color.clear
                                .onAppear {
                                    Task<Void, Never> {
                                        await model.loadPage()
                                    }
                                }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init())
                }
                .listStyle(.plain)
                .refreshable(action: model.refresh)

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
        }
    }
}

#Preview {
    WatchHistoryScreen(model: .init())
}

#Preview {
    WatchHistoryScreen(model: .init(claims: [
        .init(
            name: "claim",
            signingChannelRef: .init(.init(
                name: "channel"
            ))
        )
    ]))
}
