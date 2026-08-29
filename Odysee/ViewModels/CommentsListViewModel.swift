//
//  CommentsListViewModel.swift
//  Odysee
//
//  Created by Keith on 18/08/2026.
//

import Foundation

@available(iOS 16, *)
extension CommentsListRecursive {
    @MainActor
    class ViewModel: ObservableObject {
        private var page = 1

        @Published private(set) var isLastPage = false
        @Published private(set) var replies: [Comment] = []

        func loadPage(parentId: Comment.ID, commentsModel: Comments.ViewModel) async {
            do {
                let list = try await commentsModel.listComments(parentId: parentId, page: page)

                replies.append(contentsOf: list.items)
                isLastPage = list.isLastPage

                page += 1
            } catch {
                Helper.showError(error: error)
            }
        }
    }
}
