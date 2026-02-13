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
        var body: some View {
            ProgressView()
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

    var body: some View {
        NavigationView {
            NavigationLink(isActive: $navigator.active) {
                Screen()
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
    ManageFollowingScreen.Screen()
}
