//
//  PlaylistsScreen.swift
//  Odysee
//
//  Created by Keith Toh on 09/04/2026.
//

import SwiftUI

struct PlaylistsScreen: View {
    @ObservedObject var model: ViewModel

    // FIXME: Localize
    private enum SortBy: String, CaseIterable, Identifiable {
        case name
        case updated
        case videoCount = "Video Count"

        var id: String { rawValue }
    }

    // FIXME: Localize
    private enum FilterBy: String, CaseIterable, Identifiable {
        case all
        case `private`
        case `public`
        case edited
        case saved

        var id: String { rawValue }
    }

    @State private var sortBy: SortBy = .name
    @State private var sortAsc: Bool = true

    @State private var filterBy: FilterBy = .all

    @State private var search: String = ""

    var collections: [SharedPreference.Collection] {
        if model.refreshing {
            return []
        }

        let all: [SharedPreference.Collection] = switch filterBy {
        case .all:
            model.unpublishedCollections + model.publishedCollections + model.savedCollections
        case .private:
            model.unpublishedCollections
        case .public:
            model.publishedCollections
        // FIXME: What's this
        case .edited:
            []
        case .saved:
            model.savedCollections
        }

        let searched = if search.isEmpty {
            all
        } else {
            all.filter {
                $0.titleOrName.localizedStandardContains(search)
            }
        }

        return searched.sorted {
            let result = switch sortBy {
            case .name:
                $0.titleOrName < $1.titleOrName
            case .updated:
                $0.updatedAt < $1.updatedAt
            case .videoCount:
                $0.count < $1.count
            }

            return sortAsc ? result : !result
        }
    }

    var body: some View {
        GeometryReader { metrics in
            ZStack {
                List {
                    Group {
                        if !model.refreshing && collections.isEmpty {
                            Image("spaceman_sad")
                                .resizable()
                                .scaledToFit()
                                // Image is roughly a square
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: min(metrics.size.height / 2, metrics.size.width / 2),
                                    alignment: .center
                                )
                                .accessibilityHidden(true)

                            Text("Nothing here")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        ForEach(collections) { collection in
                            // UIKit action, but disclosure using empty NavigationLink
                            Button {
                                let vc = AppDelegate.shared.mainViewController?.storyboard?
                                    .instantiateViewController(identifier: "file_view_vc") as! FileViewController
                                vc.claim = collection.asClaim

                                AppDelegate.shared.mainNavigationController?.view.layer.add(
                                    Helper.buildFileViewTransition(),
                                    forKey: kCATransition
                                )
                                AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: false)
                            } label: {
                                NavigationLink {
                                    EmptyView()
                                } label: {
                                    PlaylistListItem(collection: collection)
                                }
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
                }
                .listStyle(.plain)
                .refreshable(action: model.refresh)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            let pickerSelection = Binding<SortBy> {
                                sortBy
                            } set: {
                                if sortBy == $0 {
                                    sortAsc = !sortAsc
                                }
                                sortBy = $0
                            }

                            Picker("Sort By", selection: pickerSelection) {
                                ForEach(SortBy.allCases) { type in
                                    Group {
                                        if type == sortBy {
                                            Label(
                                                type.rawValue.capitalized,
                                                systemImage: sortAsc ? "chevron.up" : "chevron.down"
                                            )
                                        } else {
                                            Text(type.rawValue.capitalized)
                                        }
                                    }
                                    .tag(type)
                                }
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        Menu("Filter", systemImage: "line.3.horizontal.decrease") {
                            Picker("Filter By", selection: $filterBy) {
                                ForEach(FilterBy.allCases) { type in
                                    Text(type.rawValue.capitalized)
                                        .tag(type)
                                }
                            }
                        }
                    }
                }
                .searchable(text: $search)
                .apply {
                    if #available(iOS 26, *) {
                        $0.searchToolbarBehavior(.minimize)
                    } else {
                        $0
                    }
                }

                ProgressView()
                    .controlSize(.large)
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
}

#Preview {
    PlaylistsScreen(model: .init())
}
