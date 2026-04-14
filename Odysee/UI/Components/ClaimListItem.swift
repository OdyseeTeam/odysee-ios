//
//  ClaimListItem.swift
//  Odysee
//
//  Created by Keith Toh on 17/03/2026.
//

import CachedAsyncImage
import SwiftUI

/// Displays last playback position (progress bar), if present in `claim`
/// It's up to the caller ViewModel to fetch last playback position, if desired
struct ClaimListItem: View {
    var claim: Claim

    @ScaledMetric private var titleSize: CGFloat = 14
    @ScaledMetric private var secondarySize: CGFloat = 12
    @ScaledMetric private var smallestSize: CGFloat = 11

    static let imageWidth: Double = 160

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Group {
                if let url = claim.value?.thumbnail?.url.flatMap(URL.init)?
                    .makeImageURL(spec: ClaimTableViewCell.thumbImageSpec)
                {
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
            .overlay(alignment: .bottomTrailing) {
                Group {
                    switch claim.valueType ?? .stream {
                    case .channel:
                        Text("\(Image(systemName: "at"))")
                    case .stream:
                        if let duration = claim.value?.video?.duration ?? claim.value?.audio?.duration {
                            let durationText = if duration < 60 {
                                String(format: "00:%02d", duration)
                            } else {
                                Helper.durationFormatter.string(from: TimeInterval(duration)) ?? ""
                            }

                            Text("\(durationText) \(Image(systemName: "video"))")
                        } else {
                            if claim.valueType == .stream && claim.value?.source == nil {
                                // Livestream
                                Text("\(Image(systemName: "web.camera"))")
                                // FIXME: add datetime
                            } else {
                                let typeImage = switch claim.value?.source?.mediaType?.split(separator: "/").first {
                                case "image":
                                    Image(systemName: "photo")
                                case "audio":
                                    Image(systemName: "headphones")
                                case "video":
                                    Image(systemName: "video")
                                case "text":
                                    Image(systemName: "text.document")
                                default:
                                    Image(systemName: "arrow.down")
                                }

                                Text("\(typeImage)")
                            }
                        }
                    case .repost:
                        // TODO: arrow.trianglehead.2.clockwise.rotate.90 on iOS 18+
                        Text("\(Image(systemName: "arrow.triangle.2.circlepath"))")
                    case .collection:
                        let playlistImage = Image(systemName: "play.square.stack")

                        if let count = claim.value?.claims?.count {
                            Text("\(playlistImage) \(count)")
                        } else {
                            Text("\(playlistImage)")
                        }
                    }
                }
                .font(.system(size: secondarySize))
                .foregroundStyle(.white)
                .padding(2)
                .background(.black)
                .padding(.bottom.union(.trailing), 4)
            }
            .overlay(alignment: .bottomLeading) {
                if let duration = claim.value?.video?.duration ?? claim.value?.audio?.duration,
                   duration > 0 && claim.lastPosition > 0
                {
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                .accentColor,
                                Color("primary_alt")
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(
                            width: min(1, Double(claim.lastPosition) / Double(duration)) * Self.imageWidth,
                            height: 4
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(claim.titleOrName ?? "")
                    .font(.system(size: titleSize))
                    .fontWeight(.semibold)
                    .lineLimit(3)

                if let channelClaim = claim.signingChannel {
                    Button {
                        let currentVc = UIApplication.currentViewController()
                        if let channelVc = currentVc as? ChannelViewController {
                            if channelVc.channelClaim?.claimId == channelClaim.claimId {
                                // if we already have the channel page open, don't do anything
                                return
                            }
                        } else if currentVc is FileViewController {
                            AppDelegate.shared.mainNavigationController?.popViewController(animated: false)
                        }

                        let vc = AppDelegate.shared.mainViewController?.storyboard?
                            .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
                        vc.channelClaim = channelClaim
                        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
                    } label: {
                        Text(channelClaim.titleOrName ?? "")
                            .font(.system(size: secondarySize))
                            .lineLimit(1)
                    }
                }

                Group {
                    let releaseTime = if let releaseTime = claim.value?.releaseTime,
                                         let releaseTimestamp = Double(releaseTime)
                    {
                        releaseTimestamp
                    } else {
                        Double(claim.timestamp ?? 0)
                    }
                    let confirmations = claim.confirmations ?? 0

                    if releaseTime > 0 && confirmations > 0 {
                        let date = Date(timeIntervalSince1970: releaseTime) // TODO: Timezone check / conversion?
                        Text(date.formatted(.relative(presentation: .numeric)))
                    } else {
                        Text("Pending")
                    }
                }
                .font(.system(size: smallestSize))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

@available(iOS 17, *)
#Preview(traits: .sizeThatFitsLayout) {
    let claim: Claim = .init(
        address: "bHg5cNFA8bF32CF6M8J3BndyZXqzreRjHz",
        amount: "0.001",
        canonicalUrl: "lbry://@Odysee#8/FutureofOdyseeVideo#0",
        claimId: "05dbe782f1d8588251b80365610eda80920d8278",
        claimOp: "update",
        confirmations: 395_148,
        height: 1_596_480,
        isChannelSignatureValid: true,
        meta: .init(
            effectiveAmount: "148.6549",
        ),
        name: "FutureofOdyseeVideo",
        normalizedName: "futureofodyseevideo",
        nout: 0,
        permanentUrl: "lbry://FutureofOdyseeVideo#05dbe782f1d8588251b80365610eda80920d8278",
        shortUrl: "lbry://FutureofOdyseeVideo#0",
        signingChannelRef: .init(.init(
            canonicalUrl: "lbry://@Odysee#8",
            name: "@Odysee",
            normalizedName: "@odysee",
            value: .init(
                title: "Odysee",
            ),
            valueType: .channel,
        )),
        repostedClaimRef: nil,
        timestamp: 1_720_561_767,
        txid: "60bff0a555ce23207f9480184d0352c2df9df740463842999084c3487b2b5860",
        type: "claim",
        value: .init(
            title: "VIDEO: The Future of Odysee",
            description: "Our latest announcement since 2 years about the Future of Odysee",
            thumbnail: .init(
                url: "https://thumbs.odycdn.com/84900c4f1703ac76f48251fcf6c040f8.webp",
            ),
            languages: [
                "en"],
            tags: [
                "c:scheduled:show",
            ],
            locations: nil,
            publicKey: nil,
            publicKeyId: nil,
            cover: nil,
            email: nil,
            websiteUrl: nil,
            featured: nil,
            license: "None",
            licenseUrl: nil,
            releaseTime: "1720636380",
            author: nil,
            fee: nil,
            streamType: "video",
            source: .init(
                sdHash: "323be2060c9f6c7877afc5feec4eb4c0a35eec00ec6439a47a910e6379f58090d77d0a26e6023fea2ea792244ded4e49",
                mediaType: "video/mp4",
                hash: "e464336ec7e03daf65e4a7b2f1eca9c3b9af92f89b1c92ff7cb2046e02a699b9fa25352b2304c519cf29554e10439908",
                name: "The Future of Odysee.mp4",
                size: "171208053",
            ),
            video: .init(
                duration: 344,
                height: 1080,
                width: 1920,
                os: nil,
            ),
            audio: nil,
            image: nil,
            software: nil,
            claims: nil,
        ),
        valueType: .stream,
        selected: false,
        featured: false,
    )

    ClaimListItem(claim: claim)
}
