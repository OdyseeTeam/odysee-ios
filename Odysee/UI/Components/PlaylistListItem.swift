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

    @ScaledMetric private var titleSize: CGFloat = 14
    @ScaledMetric private var secondarySize: CGFloat = 12
    @ScaledMetric private var smallestSize: CGFloat = 11

    static let imageWidth: Double = 160

    @State private var updatedAt: String = ""

    /// Only present if in PlaylistsScreen
    // FIXME: Make sure others don't crash due to nonexistent
    @EnvironmentObject private var playlistsModel: PlaylistsScreen.ViewModel

    var body: some View {
        NavigationLink {
            PlaylistDetailScreen(collection: collection)
                .environmentObject(playlistsModel)
        } label: {
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
                    } else if collection.isPublic, collection.items.claimIds != nil {
                        await {
                            do {
                                guard let claimId = collection.items.claimIds?.first else {
                                    return nil
                                }

                                let claimSearch = try await BackendMethods.claimSearch.call(params: .init(
                                    claimIds: [claimId],
                                ))

                                if let thumbnail = claimSearch.items.first?.value?.thumbnail?.url {
                                    return URL(string: thumbnail)
                                } else {
                                    return nil
                                }
                            } catch {
                                Helper.showError(error: error)
                                return nil
                            }
                        }()
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

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if collection.origin == .edited {
                            Image(systemName: "icloud.and.arrow.up")
                                .tint(.primary)
                        }

                        Text("\(collection.titleOrName)")
                            .font(.system(size: titleSize))
                            .fontWeight(.semibold)
                            .lineLimit(3)

                        if collection.count > 0 {
                            Spacer()

                            Button("Play", systemImage: "play.circle") {
                                Helper.openFileVc(collection.asClaim)
                            }
                            .font(.system(size: 24))
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }

                    if collection.isPublic,
                       let channel = collection.originalClaim?.signingChannel,
                       let publisher = channel.titleOrName
                    {
                        // FIXME: Accesibility
                        Button {
                            Helper.openChannelVc(channel)
                        } label: {
                            Text(publisher)
                                .font(.system(size: secondarySize))
                                .lineLimit(1)
                                .accessibilityLabel("Created by \(publisher)")
                        }
                        .buttonStyle(.borderless)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        Text("\(Image(systemName: "play.square.stack")) \(collection.count)")

                        if collection.isPublic {
                            Text("\(Image(systemName: "eye")) Public")
                        } else {
                            Text("\(Image(systemName: "lock")) Private")
                        }
                    }

                    if collection.updatedAt > 0 {
                        Text("Updated \(updatedAt)")
                            .onAppear {
                                // TODO: Timezone check / conversion?
                                let date = Date(timeIntervalSince1970: Double(collection.updatedAt))
                                    .addingTimeInterval(-1)
                                updatedAt = date.formatted(.relative(presentation: .numeric))
                            }
                    } else {
                        Text("Pending")
                    }
                }
                .font(.system(size: smallestSize))
            }
            .padding(.leading, 16)
            .padding(.vertical, 8)
        }
    }
}

@available(iOS 17, *)
#Preview(traits: .sizeThatFitsLayout) {
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
