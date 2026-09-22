//
//  Comments.swift
//  Odysee
//
//  Created by Keith on 31/07/2026.
//

import SwiftUI

@available(iOS 16, *)
struct Comments: View {
    // FIXME: hoist state to not reload when reappear
    @StateObject var model: ViewModel
    @State var expanded: Set<Comment.ID> = .init()

    @Namespace private var topId

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List {
                    VStack {
                        TitleSort(model: model)

                        CommentPostForm(
                            model: model,
                            scrollProxy: proxy
                        )
                        .padding(.bottom)
                    }
                    .id(topId)

                    // FIXME: No comments
                    CommentsList(expanded: $expanded, comments: model.comments)
                        .environmentObject(model)
                        .environment(\.parentId, nil)

                    if !model.isLastPage {
                        Color.clear
                            .onAppear {
                                Task {
                                    await model.loadPage()
                                }
                            }
                    }
                }
                .avoidMiniPlayer()
                .environment(\.defaultMinListRowHeight, 0)
                .listStyle(.plain)
                .task { // Use for await rather than onChange, to capture duplicate values
                    for await replyTo in model.$replyTo.values {
                        if replyTo != nil {
                            withAnimation {
                                proxy.scrollTo(topId)
                            }
                        }
                    }
                }
            }

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

@available(iOS 16, *)
extension Comments {
    struct TitleSort: View {
        @ObservedObject var model: Comments.ViewModel

        var body: some View {
            HStack {
                Group {
                    if let totalComments = model.totalComments {
                        Text("^[\(totalComments) comment](inflect: true)")
                    } else {
                        Text("Comments")
                    }
                }
                .font(.title2)

                Spacer()

                Menu("Sort", systemImage: Icons.sort) {
                    Picker("Sort By", selection: $model.sortBy) {
                        ForEach(Comments.ViewModel.SortBy.allCases) { type in
                            Text(type.rawValue.capitalized)
                                .tag(type)
                        }
                    }
                }
                .labelStyle(.iconOnly)
            }
        }
    }
}

/// Preview of ProgressView
@available(iOS 16, *)
#Preview {
    // FIXME: Change to odysee
    Comments(model: .init(claimId: "989f7977d0394ec45389ba05c50109dd958b655e"))
}
