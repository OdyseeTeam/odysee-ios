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
    @StateObject private var publishesModel: PublishesScreen.ViewModel = .init()
    @StateObject private var watchHistoryModel: WatchHistoryScreen.ViewModel = .init()

    var body: some View {
        Picker("Tab", selection: $selectedTab) {
            Text("Publishes").tag(Tab.publishes)
            Text("Watch History").tag(Tab.watchHistory)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        switch selectedTab {
        case .publishes:
            PublishesScreen(model: publishesModel)
        case .watchHistory:
            WatchHistoryScreen(model: watchHistoryModel)
        }
    }
}

#Preview {
    LibraryScreen()
}
