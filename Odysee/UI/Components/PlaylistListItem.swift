//
//  PlaylistListItem.swift
//  Odysee
//
//  Created by Keith Toh on 14/04/2026.
//

import CachedAsyncImage
import SwiftUI

struct PlaylistListItem: View {
    var collection: SharedPreference.Collection

    @State private var thumbnailUrl: URL?

    static let imageWidth: Double = 160

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Group {
                if let url = thumbnailUrl?.makeImageURL(spec: ClaimTableViewCell.thumbImageSpec) {
                    CachedAsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else if phase.error != nil {
                            Color.clear
                        } else {
                            ProgressView()
                        }
                    }
                } else {
                    Image("spaceman")
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: Self.imageWidth, height: 90)
            .clipped()
            .background(Color("light_primary"))
            .task {
                thumbnailUrl = if let url = collection.thumbnail?.url {
                    url
                } else {
                    await {
                        do {
                            guard let item = collection.items.uris.first else {
                                return nil
                            }

                            let resolve = try await BackendMethods.resolve.call(params: .init(
                                urls: [item.description],
                            ))

                            if let thumbnail = resolve.claims.values.first?.value?.thumbnail?.url {
                                return URL(string: thumbnail)
                            } else {
                                return nil
                            }
                        } catch {
                            Helper.showError(error: error)
                            return nil
                        }
                    }()
                }
            }

            let count = collection.itemCount ?? collection.items.uris.count
            Text("\(Image(systemName: "play.square.stack")) \(count)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    PlaylistListItem(collection: .init(
        id: "A",
        items: .init(uris: [
            LbryUri.tryParse(url: "lbry://@Odysee#8/FutureofOdyseeVideo#0", requireProto: true) ?? LbryUri(),
        ]),
        name: "named",
        type: .playlist,
        updatedAt: 1_776_134_690,
    ))
}
