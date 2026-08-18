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
        CommentsList(
            commentsByParent: model.commentsByParent,
            authors: model.authors,
            expanded: $expanded,
            model: model
        )
    }
}

@available(iOS 16, *)
#Preview {
    Comments()
}
