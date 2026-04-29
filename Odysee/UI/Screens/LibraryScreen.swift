//
//  LibraryScreen.swift
//  Odysee
//
//  Created by Keith Toh on 31/03/2026.
//

import SwiftUI

struct LibraryScreen: View {
    enum Tab: String, CaseIterable, Identifiable {
        case publishes
        case watchHistory
        case playlists

        var id: Self { self }
    }

    @AppStorage("library#selectedTab") private var selectedTab: Tab = .publishes

    var body: some View {
        NavigationView {
            VStack {
                Picker("Tab", selection: $selectedTab) {
                    Text("Publishes").tag(Tab.publishes)
                    Text("Watch History").tag(Tab.watchHistory)
                    Text("Playlists").tag(Tab.playlists)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch selectedTab {
                case .publishes:
                    PublishesScreen()
                case .watchHistory:
                    WatchHistoryScreen()
                case .playlists:
                    PlaylistsScreen()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    LibraryScreen()
}
