//
//  ChannelScreen.swift
//  Odysee
//
//  Created by Keith on 21/09/2026.
//

import SwiftUI

@available(iOS 16, *)
extension ChannelScreen {
    enum Channel {
        case claim(Claim)
        case uri(name: String, claimId: String)
    }
}

@available(iOS 16, *)
struct ChannelScreen: View {
    @State var channel: Channel

    @State private var error: Error?
    @State private var abandoned: Bool = false

    @State private var tab: Int = 2

    // MARK: Sticky header state variables

    @State private var offset: CGFloat = 0

    var body: some View {
        if let error {
            Text(error.localizedDescription)
                .foregroundStyle(.red)
        } else if case let .claim(claim) = channel {
            TabView(selection: $tab) {
                FrameTrackingList(offset: $offset, tag: 0, selection: $tab) {
                    Text("A")
                }

                FrameTrackingList(offset: $offset, tag: 1, selection: $tab) {
                    Text("b")
                }

                Comments(
                    offset: $offset, tag: 2, selection: $tab,
                    // FIXME: Shouldn't be nil in model
                    model: .init(claimId: claim.claimId ?? "")
                )
            }
            .sharedHeaderPageView(
                offset: $offset,
                headerHeight: 300,
                headerMinHeight: 80
            ) {
                ScrollViewHeaderImage(Image(.spacemanCover))
            }
        } else if case let .uri(name, claimId) = channel {
            if abandoned {
                // FIXME: Maybe
                Text("This channel may have been unpublished.")
            } else {
                ProgressView()
                    .task {
                        do {
                            let resolve = try await BackendMethods.resolve.call(params: .init(
                                urls: [LbryUri.normalize(url: "\(name)#\(claimId)")]
                            ))

                            guard let claim = resolve.claims.values.first else {
                                abandoned = true
                                return
                            }

                            channel = .claim(claim)
                        } catch {
                            self.error = error
                        }
                    }
            }
        }
    }
}

@available(iOS 16, *)
#Preview {
    ChannelScreen(channel: .uri(
        // FIXME: Change to odysee
        name: "@ktprograms", claimId: "989f7977d0394ec45389ba05c50109dd958b655e"
    ))
}
