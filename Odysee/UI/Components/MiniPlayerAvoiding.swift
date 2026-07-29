//
//  MiniPlayerAvoiding.swift
//  Odysee
//
//  Created by Keith on 29/07/2026.
//

import SwiftUI

/// Insert this at the end of a List/ScrollView to add "content inset" when miniplayer visible
///
/// This must be part of the list's content (i.e. List -> ForEach, not direct List)
struct MiniPlayerAvoiding: View {
    @State private var miniPlayerTop: Double = 0

    var body: some View {
        Color.clear
            .frame(height: miniPlayerTop)
            .task {
                guard let mainController = AppDelegate.shared.mainController else {
                    return
                }

                for await new in mainController.miniPlayerTop.values {
                    miniPlayerTop = new
                }
            }
    }
}

#Preview {
    MiniPlayerAvoiding()
}
