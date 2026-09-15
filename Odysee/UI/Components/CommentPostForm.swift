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

    var body: some View {
        if !Account.signedIn /* if no channels */ {
            Text("FIXME")
//        } else if globals.channels.count == 0 {
//            Text("Create")
        } else {
            VStack {
                ChannelPickerNil(
                    title: model.replyTo != nil ? "Replying as" : "Comment as",
                    channel: $model.channel,
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

    @ObservedObject private var account = Account.shared
    private var channels: [Claim] {
        account.channels
    }

    var body: some View {
        if channels.count > 0 {
            Picker(title, selection: $channel) {
                ForEach(channels) {
                    Text($0.name ?? "")
                        .tag($0)
                }

                Divider().tag(nil as Claim?)
            }
            .pickerStyle(.menu)
            .onAppear {
                Task {
                    for await defaultChannelId in Wallet.$prefs.defaultChannelId {
                        if channel == nil, let defaultChannelId {
                            channel = channels.first { $0.claimId == defaultChannelId }
                        }
                    }
                }
            }
        } else {
            ProgressView()
        }
    }
}

@available(iOS 16, *)
#Preview {
    ScrollViewReader { proxy in
        CommentPostForm(model: .init(), scrollProxy: proxy)
    }
}
