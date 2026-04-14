//
//  PlaylistsScreen.swift
//  Odysee
//
//  Created by Keith Toh on 09/04/2026.
//

import SwiftUI

struct PlaylistsScreen: View {
    @State private var unpublishedCollections = [SharedPreference.Collection]()

    @State private var publishedCollections = [Claim]()

    var body: some View {
        // FIXME: Sort options
        List(unpublishedCollections) { collection in
            NavigationLink {
                Text("Hi")
            } label: {
                PlaylistListItem(collection: collection)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
        }
        .listStyle(.plain)
        .task {
            unpublishedCollections = Array(await Wallet.shared.unpublishedCollections.values)

            for await newUnpublishedCollections in await Wallet.shared.sUnpublishedCollections {
                unpublishedCollections = Array(newUnpublishedCollections.values)
            }
        }
    }
}

#Preview {
    PlaylistsScreen()
}
