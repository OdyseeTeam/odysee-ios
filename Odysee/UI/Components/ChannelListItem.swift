//
//  ChannelListItem.swift
//  Odysee
//
//  Created by Keith Toh on 13/02/2026.
//

import CachedAsyncImage
import SwiftUI

struct ChannelListItem: View {
    let channel: Claim

    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 20) {
            Group {
                if let url = channel.value?.thumbnail?.url {
                    CachedAsyncImage(url: URL(string: url)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                                .clipShape(.circle)
                        } else if phase.error != nil {
                            Color.clear
                        } else {
                            ProgressView()
                        }
                    }
                } else {
                    Color.clear
                }
            }
            .frame(width: 40 * scale, height: 40 * scale)

            VStack(alignment: .leading) {
                Text(channel.titleOrName ?? "")

                if channel.value?.title != nil {
                    Text(channel.name ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    let claims: [Claim] = [
        // All info present
        .init(
            claimId: "all-info-present",
            name: "@Odysee",
            value: .init(
                title: "Odysee",
                thumbnail: .init(url: "https://thumbs.odycdn.com/5a920753363de87d6f1f4b0d90b44706.webp"),
            ),
        ),
        // Missing title
        .init(
            claimId: "missing-title",
            name: "@Odysee",
            value: .init(
                thumbnail: .init(url: "https://thumbs.odycdn.com/5a920753363de87d6f1f4b0d90b44706.webp"),
            ),
        ),
        // Missing name
        .init(
            claimId: "missing-name",
            value: .init(
                thumbnail: .init(url: "https://thumbs.odycdn.com/5a920753363de87d6f1f4b0d90b44706.webp")
            ),
        ),
        // Missing thumbnail
        .init(
            claimId: "missing-thumbnail",
            name: "@Odysee",
            value: .init(
                title: "Odysee",
            ),
        ),
        // Invalid thumbnail url
        .init(
            claimId: "invalid-thumbnail",
            name: "@Odysee",
            value: .init(
                title: "Odysee",
                thumbnail: .init(url: ":a\\f#%f&ac"),
            ),
        ),
        // Broken thumbnail url
        .init(
            claimId: "broken-thumbnail",
            name: "@Odysee",
            value: .init(
                title: "Odysee",
                thumbnail: .init(url: "https://"),
            ),
        ),
        // 404 thumbnail url
        .init(
            claimId: "404-thumbnail",
            name: "@Odysee",
            value: .init(
                title: "Odysee",
                thumbnail: .init(url: "https://thumbs.odycdn.com/asdfjkl"),
            ),
        ),
    ]

    List(claims) { claim in
        ChannelListItem(channel: claim)
    }
}
