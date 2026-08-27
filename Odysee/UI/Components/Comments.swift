//
//  Comments.swift
//  Odysee
//
//  Created by Keith on 31/07/2026.
//

import SwiftUI

@available(iOS 16, *)
struct Comments: View {
    @StateObject private var model: ViewModel = .init()
    @State var expanded: Set<Comment.ID> = .init()

    var body: some View {
        ZStack {
            List {
                CommentPostForm()
                    .padding(.bottom)

                CommentsListRecursive(expanded: $expanded)
                    .environmentObject(model)
                    .environment(\.parentId, nil)

                MiniPlayerAvoiding()
                    .listRowSeparator(.hidden)
            }
            .environment(\.defaultMinListRowHeight, 0)
            .listStyle(.plain)

            ProgressView()
                .controlSize(.large)
                .tint(.white)
                .padding()
                .background {
                    Color.accentColor
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .apply {
                    if model.inProgress {
                        $0
                    } else {
                        $0.hidden()
                    }
                }
        }
    }
}

/// Preview of ProgressView
@available(iOS 16, *)
#Preview {
    Comments()
}
