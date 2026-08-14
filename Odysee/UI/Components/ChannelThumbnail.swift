//
//  ChannelThumbnail.swift
//  Odysee
//
//  Created by Keith on 13/08/2026.
//

import CachedAsyncImage
import SwiftUI

struct ChannelThumbnail: View {
    var claim: Claim

    @ScaledMetric private var scale = 1

    /// <https://github.com/OdyseeTeam/odysee-frontend/blob/c605de2a2f461d61fcc4745dd1008510ef1e3737/ui/component/channelThumbnail/view.tsx#L89-L95>
    /// <https://github.com/OdyseeTeam/odysee-frontend/blob/c605de2a2f461d61fcc4745dd1008510ef1e3737/ui/scss/component/_channel.scss#L612-L630>
    private var background: Color {
        if claim.name == Claim.anonymous.name {
            return Color(red: 204, green: 204, blue: 204)
        } else {
            guard let char = claim.name?.first(where: { $0 != "@" })?.asciiValue else {
                return Color("light_primary")
            }

            return switch abs((Int(char) - 65) % 4) {
            case 0:
                Color(red: 116 / 255.0, green: 143 / 255.0, blue: 252 / 255.0)
            case 1:
                Color(red: 255 / 255.0, green: 168 / 255.0, blue: 85 / 255.0)
            case 2:
                Color(red: 51 / 255.0, green: 154 / 255.0, blue: 240 / 255.0)
            default:
                Color(red: 236 / 255.0, green: 131 / 255.0, blue: 131 / 255.0)
            }
        }
    }

    var body: some View {
        Group {
            if let url = claim.value?.thumbnail?.url {
                CachedAsyncImage(url: URL(string: url)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                    } else if phase.error != nil {
                        Color.clear
                    } else {
                        ProgressView()
                    }
                }
            } else {
                Image("spaceman")
                    .resizable()
                    .background(background)
            }
        }
        .scaledToFill()
        .clipShape(.circle)
        .frame(width: 40 * scale, height: 40 * scale)
    }
}

@available(iOS 17, *)
#Preview(traits: .sizeThatFitsLayout) {
    ChannelThumbnail(
        claim: .init(
            value: .init(
                thumbnail: .init(
                    url: "https://thumbs.odycdn.com/5a920753363de87d6f1f4b0d90b44706.webp"
                )
            )
        )
    )

    ChannelThumbnail(
        claim: .init(
            name: "@Odysee",
        )
    )

    ChannelThumbnail(
        claim: .init(
            name: "Anonymous",
        )
    )
}
