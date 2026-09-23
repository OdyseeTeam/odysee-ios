//
//  MiniPlayerAvoiding.swift
//  Odysee
//
//  Created by Keith on 29/07/2026.
//

import SwiftUI

struct MiniPlayerAvoiding: ViewModifier {
    @State private var miniPlayerTop: Double = 0

    func body(content: Content) -> some View {
        content
            // FIXME: (iOS 17) Change to safeAreaPadding
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: miniPlayerTop)
                    .task {
                        guard let mainController = AppDelegate.shared.mainController else {
                            return
                        }

                        // FIXME: rename to top
                        for await new in mainController.miniPlayerTop.values {
                            miniPlayerTop = new
                        }
                    }
            }
    }
}

@MainActor
extension List {
    func avoidMiniPlayer() -> some View {
        modifier(MiniPlayerAvoiding())
    }
}

@MainActor
extension ScrollView {
    func avoidMiniPlayer() -> some View {
        modifier(MiniPlayerAvoiding())
    }
}
