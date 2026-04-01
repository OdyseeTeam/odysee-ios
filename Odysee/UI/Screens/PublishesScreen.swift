//
//  PublishesScreen.swift
//  Odysee
//
//  Created by Keith Toh on 31/03/2026.
//

import SwiftUI

struct PublishesScreen: View {
    @ObservedObject var model: ViewModel

    var body: some View {
        Text("Publishes")
    }
}

#Preview {
    PublishesScreen(model: .init())
}
