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

    var body: some View {
        NavigationLink {
            PlaylistDetailScreen(collection: collection)
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
                    } else if collection.isPublic {
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
                        Text(collection.titleOrName)
                            .font(.system(size: titleSize))
                            .fontWeight(.semibold)
                            .lineLimit(3)

                        if collection.count > 0 {
                            Spacer()

                            Button("Play", systemImage: "play.circle") {
                                let vc = AppDelegate.shared.mainViewController?.storyboard?
                                    .instantiateViewController(identifier: "file_view_vc") as! FileViewController
                                vc.claim = collection.asClaim

                                AppDelegate.shared.mainNavigationController?.view.layer.add(
                                    Helper.buildFileViewTransition(),
                                    forKey: kCATransition
                                )
                                AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: false)
                            }
                            .font(.system(size: 24))
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }

                    if collection.isPublic,
                       let publisher = collection.originalClaim?.signingChannel?.titleOrName
                    {
                        Text(publisher)
                            .font(.system(size: secondarySize))
                            .lineLimit(1)
                            // TODO: Accessibility test
                            .accessibilityLabel(Text("Created by \(publisher)"))
                    }

                    Spacer(minLength: 0)

                    HStack {
                        let count = collection.itemCount ?? collection.items.uris.count
                        Text("\(Image(systemName: "play.square.stack")) \(count)")

                        if collection.isPublic {
                            Text("\(Image(systemName: "eye")) Public")
                        } else {
                            Text("\(Image(systemName: "lock")) Private")
                        }
                    }

                    let date = Date(timeIntervalSince1970: Double(collection.updatedAt))
                    // TODO: Timezone check / conversion?
                    Text("Updated \(date.formatted(.relative(presentation: .numeric)))")
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
