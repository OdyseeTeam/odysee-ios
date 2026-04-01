//
//  WatchHistoryScreen.swift
//  Odysee
//
//  Created by Keith Toh on 18/03/2026.
//

import SwiftUI

struct WatchHistoryScreen: View {
    @ObservedObject var model: ViewModel

    var body: some View {
        Text("Watch History")
    }
}

#Preview {
    WatchHistoryScreen(model: .init())
}
