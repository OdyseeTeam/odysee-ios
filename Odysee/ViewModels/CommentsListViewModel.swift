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
        static let pageSize = 10
        private var page = 1

        @Published private(set) var isLastPage = false
        @Published private(set) var replies: [Comment] = []

        func loadPage(parentId: Comment.ID?, commentsModel: Comments.ViewModel) async {
            do {
                let list = try await commentsModel.listComments(params: .init(
                    claimId: "80d2590ad04e36fb1d077a9b9e3a8bba76defdf8",
//                    claimId: "989f7977d0394ec45389ba05c50109dd958b655e",
                    parentId: parentId,
                    page: page,
                    pageSize: Self.pageSize,
                    topLevel: parentId == nil,
                    sortBy: parentId == nil ? .popularity : .oldest // FIXME: Option
                ))

                replies.append(contentsOf: list.items)
                isLastPage = list.isLastPage

                page += 1
            } catch {
                Helper.showError(error: error)
            }
        }
    }
}
