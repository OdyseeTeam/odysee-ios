//
//  CommentPostForm.swift
//  Odysee
//
//  Created by Keith on 24/08/2026.
//

import SwiftUI

@available(iOS 16, *)
struct CommentPostForm: View {
    @ObservedObject var model: Comments.ViewModel
    var scrollProxy: ScrollViewProxy

    @State private var channels: [Claim]?

    var body: some View {
        if !Lbryio.isSignedIn() /* if no channels */ {
            Text("FIXME")
        } else if let channels, channels.count == 0 {
            Text("Create")
        } else {
            VStack {
                ChannelPickerNil(
                    title: model.replyTo != nil ? "Replying as" : "Comment as",
                    channel: $model.channel,
                    channels: $channels
                )

                if let replyTo = model.replyTo {
                    Button {
                        withAnimation {
                            scrollProxy.scrollTo(replyTo.id, anchor: .center)
                        }
                    } label: {
                        HStack {
                            Color.accentColor
                                .frame(width: 2)

                            CommentText(replyTo.comment)
                                .lineLimit(1)
                                .opacity(0.5)

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }

                TextField(
                    "Comment Text",
                    text: $model.postText.max(Helper.commentMaxLength),
                    prompt: Text("Say something about this..."),
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Comment") {}
                        .buttonStyle(.borderedProminent)
                        .disabled(model.postText.isBlank)

                    if let replyTo = model.replyTo {
                        Button("Cancel") {
                            model.replyTo = nil

                            withAnimation {
                                scrollProxy.scrollTo(replyTo.id, anchor: .center)
                            }
                        }
                        .buttonStyle(.borderless)
                    }

                    Spacer()

                    Text(String(model.postText.count)) + Text("/\(String(Helper.commentMaxLength))")
                }
            }
        }
    }
}

struct ChannelPickerNil: View {
    var title: String
    @Binding var channel: Claim?
    @Binding var channels: [Claim]?

    var body: some View {
        if let channels {
            Picker(title, selection: $channel) {
                ForEach(channels) {
                    Text($0.name ?? "")
                        .tag($0)
                }

                Divider().tag(nil as Claim?)
            }
            .pickerStyle(.menu)
        } else {
            ProgressView()
                .onAppear {
                    Task {
                        do {
                            let claimList = try await BackendMethods.claimList.call(params: .init(
                                claimType: [.channel],
                                page: 1,
                                pageSize: 999,
                                resolve: true
                            ))

                            let channels = claimList.items.filter { $0.claimId != Claim.anonymous.claimId }
                            Lbry.ownChannels = channels

                            if let defaultChannelId = Wallet.prefs.defaultChannelId {
                                channel = channels.first { $0.claimId == defaultChannelId }
                            }

                            self.channels = channels
                        } catch {
                            Helper.showError(message: __("Error loading channels: \(error.localizedDescription)"))

                            channel = nil
                            channels = []
                        }

                        for await defaultChannelId in Wallet.$prefs.defaultChannelId {
                            if channel == nil, let channels, let defaultChannelId {
                                channel = channels.first { $0.claimId == defaultChannelId }
                            }
                        }
                    }
                }
        }
    }
}

@available(iOS 16, *)
#Preview {
    ScrollViewReader { proxy in
        CommentPostForm(model: .init(), scrollProxy: proxy)
    }
}
