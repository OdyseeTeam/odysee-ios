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
    @State private var expanded: Set<Comment.ID> = .init()

    @Namespace private var topId

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List {
                    VStack {
                        TitleSort(model: model)

                        CommentPostForm(
                            replyTo: $model.replyTo,
                            scrollProxy: proxy
                        )
                        .padding(.bottom)
                        .id(topId)
                        // FIXME: onChange means Reply -> Go to -> Reply doesn't scroll back up again
                        .onChange(of: model.replyTo) {
                            if $0 != nil {
                                withAnimation {
                                    proxy.scrollTo(topId)
                                }
                            }
                        }
                    }

                    CommentsListRecursive(expanded: $expanded)
                        .environmentObject(model)
                        .environment(\.parentId, nil)

                    MiniPlayerAvoiding()
                        .listRowSeparator(.hidden)
                }
                .environment(\.defaultMinListRowHeight, 0)
                .listStyle(.plain)
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
                    if let totalItems = model.totalItems {
                        Text("^[\(totalItems) comment](inflect: true)")
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
    Comments()
}
