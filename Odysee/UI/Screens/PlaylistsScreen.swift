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
        case name = "Name"
        case updated = "Updated"
        case videoCount = "Video Count"

        var id: String { rawValue }
    }

    @State private var sortBy: SortBy = .name
    @State private var sortAsc: Bool = true

    var collections: [SharedPreference.Collection] {
        if model.refreshing {
            return []
        }

        let all = model.unpublishedCollections + model.publishedCollections

        return all.sorted {
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
        ZStack {
            List(collections) { collection in
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
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
            }
            .listStyle(.plain)
            .refreshable(action: model.refresh)
            .toolbar {
                ToolbarItem {
                    Menu("Sort", systemImage: "ellipsis") {
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
                                        Label(type.rawValue, systemImage: sortAsc ? "chevron.up" : "chevron.down")
                                    } else {
                                        Text(type.rawValue)
                                    }
                                }
                                .tag(type)
                            }
                        }
                    }
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

#Preview {
    PlaylistsScreen(model: .init())
}
