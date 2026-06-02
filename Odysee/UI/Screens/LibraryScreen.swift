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

        var id: Self { self }
    }

    @AppStorage("library#selectedTab") private var selectedTab: Tab = .publishes

    var body: some View {
        Picker("Tab", selection: $selectedTab) {
            Text("Publishes").tag(Tab.publishes)
            Text("Watch History").tag(Tab.watchHistory)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        switch selectedTab {
        case .publishes:
            PublishesScreen()
        case .watchHistory:
            WatchHistoryScreen()
        }
    }
}

#Preview {
    LibraryScreen()
}
