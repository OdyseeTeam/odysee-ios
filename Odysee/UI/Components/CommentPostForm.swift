//
//  CommentPostForm.swift
//  Odysee
//
//  Created by Keith on 24/08/2026.
//

import SwiftUI

@available(iOS 16, *)
struct CommentPostForm: View {
    var cancel: (() -> Void)?

    @State private var text: String = ""

    @State private var commentAs: Claim = .init(claimId: Lbry.defaultChannelId)

    var body: some View {
        VStack {
            ChannelPicker(title: "Comment as", channel: $commentAs, includeAnonymous: false)

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

                if let cancel {
                    Button("Cancel", action: cancel)
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
    CommentPostForm()
}
