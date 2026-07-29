//
//  WatchHistoryScreen.swift
//  Odysee
//
//  Created by Keith Toh on 18/03/2026.
//

import SwiftUI

struct WatchHistoryScreen: View {
    @StateObject var model: ViewModel = .init()

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
                            ClaimListItem(claim: claim)
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

                        MiniPlayerAvoiding()
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
    WatchHistoryScreen()
}

#Preview {
    // FIXME: @StateObject must be private
    WatchHistoryScreen(model: .init(claims: [
        .init(
            name: "claim",
            signingChannelRef: .init(.init(
                name: "channel"
            ))
        )
    ]))
}
