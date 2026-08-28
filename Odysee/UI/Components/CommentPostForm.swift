//
//  CommentPostForm.swift
//  Odysee
//
//  Created by Keith on 24/08/2026.
//

import SwiftUI

@available(iOS 16, *)
struct CommentPostForm: View {
    @Binding var replyTo: Comment?
    var scrollProxy: ScrollViewProxy

    @State private var text: String = ""

    @State private var commentAs: Claim = .init(claimId: Lbry.defaultChannelId)

    var body: some View {
        VStack {
            // FIXME: Doesn't populate at first, needs onAppear?
            ChannelPicker(
                title: replyTo != nil ? "Replying as" : "Comment as",
                channel: $commentAs,
                includeAnonymous: false
            )

            if let replyTo {
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
            }

            TextField(
                "Comment Text",
                text: $text.max(Helper.commentMaxLength),
                prompt: Text("Say something about this..."),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)

            HStack {
                Button("Comment") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(text.isBlank)

                if let replyTo {
                    Button("Cancel") {
                        self.replyTo = nil

                        withAnimation {
                            scrollProxy.scrollTo(replyTo.id, anchor: .center)
                        }
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Text(String(text.count)) + Text("/\(String(Helper.commentMaxLength))")
            }
        }
    }
}

@available(iOS 16, *)
#Preview {
    ScrollViewReader { proxy in
        CommentPostForm(replyTo: .constant(nil), scrollProxy: proxy)
    }
}
