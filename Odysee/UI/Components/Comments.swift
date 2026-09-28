//
//  Comments.swift
//  Odysee
//
//  Created by Keith on 31/07/2026.
//

import SwiftUI

// FIXME: How will this work on file_vc etc (due to not needing a shared header)
@available(iOS 16, *)
struct Comments: View {
    // MARK: Sticky header parameters

    typealias SelectionValue = Int
    @Binding var offset: CGFloat
    var tag: SelectionValue
    @Binding var selection: SelectionValue

    // MARK: Other parameters and variables

    @StateObject var model: ViewModel
    @State var expanded: Set<Comment.ID> = .init()

    @Namespace private var topId

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                FrameTrackingList(offset: $offset, tag: tag, selection: $selection) {
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
                .task { // Use for await rather than onChange, to capture duplicate values
                    for await replyTo in model.$replyTo.values {
                        if replyTo != nil {
                            withAnimation {
                                proxy.scrollTo(topId, anchor: .bottom)
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
        .tag(tag) // FIXME: Is duplicated inside FrameTrackingList, but shouldn't affect anything
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

@available(iOS 16, *)
#Preview {
    // FIXME: Change to odysee
    Comments(
        offset: .constant(0), tag: 0, selection: .constant(0),
        model: .init(claimId: "989f7977d0394ec45389ba05c50109dd958b655e")
    )
    .environment(\.stickyHeaderHeight, 100)
}
