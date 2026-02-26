//
//  ChannelListItem.swift
//  Odysee
//
//  Created by Keith Toh on 13/02/2026.
//

import CachedAsyncImage
import SwiftUI

extension ChannelListItem {
    enum Channel {
        case claim(Claim)
        case uri(name: String, claimId: String)
    }
}

struct ChannelListItem: View {
    @State private(set) var channel: Channel
    @State private(set) var error: Error?

    var otherText: String?

    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading) {
            if let error {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
            } else if case let .claim(claim) = channel {
                HStack(spacing: 20) {
                    Group {
                        if let url = claim.value?.thumbnail?.url {
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
                        Text(claim.titleOrName ?? "")

                        if claim.value?.title != nil {
                            Text(claim.name ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if case let .uri(name, claimId) = channel {
                ProgressView()
                    .task {
                        do {
                            let resolve = try await BackendMethods.resolve.call(params: .init(
                                urls: ["lbry://\(name)#\(claimId)"]
                            ))

                            guard let claim = resolve.claims.values.first else {
                                error = GenericError("Claim resolve didn't return any results")
                                return
                            }

                            channel = .claim(claim)
                        } catch {
                            self.error = error
                        }
                    }
            }

            if let otherText {
                Text(otherText)
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

    List {
        Section {
            ChannelListItem(channel: .uri(
                name: "@Odysee",
                claimId: "80d2590ad04e36fb1d077a9b9e3a8bba76defdf8"
            ))
            ChannelListItem(
                channel: .uri(
                    name: "@Odysee",
                    claimId: "80d2590ad04e36fb1d077a9b9e3a8bba76defdf8"
                ),
                error: GenericError("An error")
            )
        }

        Section {
            ForEach(claims) { claim in
                ChannelListItem(channel: .claim(claim))
            }
        }
    }
}
