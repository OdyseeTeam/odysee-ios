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
        VStack {
            ChannelPickerNil(channel: $model.channel)
//            ChannelPicker(
//                title: model.replyTo != nil ? "Replying as" : "Comment as",
//                channel: $model.channel,
//                includeAnonymous: false
//            )

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

struct ChannelPickerNil: View {
    @Binding var channel: Claim?

    @State private var channels: [Claim]?

    var body: some View {
        if let channels {
            Picker("Channel", selection: $channel) {
                ForEach(channels) {
                    Text($0.name ?? "")
                        .tag($0)
                }
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

                            let defaultChannelId = Wallet.prefs.defaultChannelId
                            channel = channels.first { $0.claimId == defaultChannelId } ?? channels.first

                            self.channels = channels
                        } catch {
                            Helper.showError(message: __("Error loading channels: \(error.localizedDescription)"))

                            channel = nil
                            channels = []
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
