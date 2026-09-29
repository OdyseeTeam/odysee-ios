//
//  ChannelScreen.swift
//  Odysee
//
//  Created by Keith on 21/09/2026.
//

import SwiftUI
import WrappingHStack

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

    @State private var tab: Int = 1

    // MARK: Sticky header state variables

    @State private var offset: CGFloat = 0

    @FontScaled(relativeTo: .body) private var bodySize

    // FIXME: model
    @State private var claims: [Claim] = []

    var body: some View {
        if let error {
            Text(error.localizedDescription)
                .foregroundStyle(.red)
        } else if case let .claim(claim) = channel {
            TabView(selection: $tab) {
                FrameTrackingList(offset: $offset, tag: 0, selection: $tab) {
                    ForEach(claims) { claim in
                        ClaimListItem(claim: claim)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init())
                }

                // FIXME: Bottom safe area (tab indicator)
                FrameTrackingList(offset: $offset, tag: 1, selection: $tab) {
                    About(claim: claim)
                }
                .environment(\.defaultMinListRowHeight, 0)

                Comments(
                    offset: $offset, tag: 2, selection: $tab,
                    // FIXME: Shouldn't be nil in model
                    model: .init(claimId: claim.claimId ?? "")
                )
            }
            .sharedHeaderPageView(
                offset: $offset,
                headerHeight: 300,
                headerMinHeight: 8
            ) {
                ScrollViewHeaderImage(Image(.spacemanCover))
                // FIXME: .blur(radius: 4)
                // FIXME: opactiy to passthrough scroll?
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(claim.titleOrName ?? "")
                        .padding()
                }
            }
            .apply {
                if #unavailable(iOS 26) {
                    $0
                        .toolbarBackground(.gray.opacity(0), for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                } else {
                    $0
                }
            }
        } else if case let .uri(name, claimId) = channel {
            if abandoned {
                // FIXME: Maybe
                Text("This channel may have been unpublished.")
            } else {
                ProgressView()
//                    .task {
                    .onAppear { Task {
                        do {
                            let resolve = try await BackendMethods.resolve.call(params: .init(
                                urls: [LbryUri.normalize(url: "\(name)#\(claimId)")]
                            ))

                            guard let claim = resolve.claims.values.first else {
                                abandoned = true
                                return
                            }

                            channel = .claim(claim)

                            claims = try await BackendMethods.claimSearch.call(params: .init(
                                claimType: [.stream, .repost],
                                page: 1,
                                pageSize: 20,
                                hasNoSource: false,
                                notTags: Constants.NotTags,
                                channelIds: [claim.claimId ?? ""],
                            )).items
                        } catch {
                            self.error = error
                        }
                    }}
            }
        }
    }

    struct About: View {
        var claim: Claim

        @FontScaled(relativeTo: .body) private var bodySize

        var body: some View {
            Group {
                if let description = claim.value?.description {
                    Section("Description") {
                        CommentText(description)
                    }
                }

                UrlSection("Contact", url: claim.value?.email, scheme: "mailto")

                UrlSection("Website", url: claim.value?.websiteUrl, scheme: "https")

                if let tags = claim.value?.tags {
                    Section("Tags") {
                        WrappingHStack {
                            ForEach(tags, id: \.self) { tag in
                                Button(tag) {
                                    // FIXME: Implement
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.top)
                    }
                }

                if let languageCodes = claim.value?.languages, languageCodes.count > 0 {
                    Section("Languages") {
                        let languages = languageCodes.map { languageCode in
                            Predefined.supportedLanguages.first {
                                languageCode == $0.code
                            }?.name ?? languageCode
                        }

                        Text(languages.formatted(.list(type: .and, width: .narrow)))
                    }
                }

                if let count = claim.meta?.claimsInChannel {
                    Section("Total Uploads") {
                        Text(String(count))
                    }
                }

                Section("Created") {
                    // FIXME: Check if needs to be in State to refresh
                    Text(Helper.formatTimestamp(Double(claim.meta?.creationTimestamp ?? claim.timestamp ?? 0)))
                }

                if let canonicalUrl = claim.canonicalUrl {
                    Section("URL") {
                        Text(canonicalUrl)
                    }
                }

                if let claimId = claim.claimId {
                    Section("Claim ID") {
                        Text(claimId)
                    }
                }

                if let amount = claim.amount,
                   let amountD = Double(amount),
                   let support = claim.meta?.supportAmount,
                   let supportD = Double(support)
                {
                    Section("Staked Credits") {
                        // FIXME: Format precision
                        Text("\(Image(.creditsIcon, size: bodySize)) \(amountD + supportD)")
                    }
                }

                // TODO: youtube badge: https://github.com/OdyseeTeam/odysee-frontend/blob/8f2001d4ee4fb6d80184baf62a58e3403f98861d/ui/page/claim/internal/claimPageComponent/internal/channelPage/tabs/aboutTab/view.tsx#L153
            }
            .listRowSeparator(.hidden)
            .listRowInsets(.init())
            .padding(.horizontal)
            .buttonStyle(.borderless)
            .textSelection(.enabled)
        }

        struct UrlSection: View {
            private let title: LocalizedStringKey
            private let urlString: String
            private let url: URL

            init?(_ title: LocalizedStringKey, url urlString: String?, scheme: String) {
                guard let urlString, var urlComponents = URLComponents(string: urlString) else {
                    return nil
                }

                if urlComponents.scheme == nil {
                    urlComponents.scheme = scheme
                }

                guard let url = urlComponents.url else {
                    return nil
                }

                self.title = title
                self.urlString = urlString
                self.url = url
            }

            var body: some View {
                Section(title) {
                    Link(urlString, destination: url)
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
