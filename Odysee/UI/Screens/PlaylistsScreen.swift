//
//  PlaylistsScreen.swift
//  Odysee
//
//  Created by Keith Toh on 09/04/2026.
//

import SwiftUI

// FIXME: (project level): "No content" shows during load (gate on wallet load somehoe)

struct PlaylistsScreen: View {
    @StateObject var model: ViewModel = .init()

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
    @State private var sortAsc = true

    @State private var filterBy: FilterBy = .all

    @State private var search = ""

    @State private var showingNewPlaylist = false
    @State private var newPlaylistTitle = ""

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
                $0.titleOrName.localizedCompare($1.titleOrName) == .orderedAscending
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
                        if !model.refreshing {
                            Text("Default Playlists")
                                .font(.title3)
                                .padding(.horizontal)

                            ForEach(model.builtinCollections) { collection in
                                PlaylistListItem(collection: collection)
                            }

                            if collections.isEmpty {
                                VStack(spacing: 16) {
                                    Image("spaceman_sad")
                                        .resizable()
                                        .scaledToFit()
                                        // Image is roughly a square
                                        .frame(
                                            maxWidth: .infinity,
                                            maxHeight: min(metrics.size.height / 2, metrics.size.width / 3),
                                            alignment: .center
                                        )
                                        .accessibilityHidden(true)

                                    Text("You can add videos to your Playlists")

                                    Text(
                                        "Do you want to find some content to save for later, or create a brand new playlist?"
                                    )
                                    .font(.footnote)
                                    .multilineTextAlignment(.center)

                                    HStack {
                                        Button("Explore!") {
                                            AppDelegate.shared.mainTabViewController?.selectedIndex = 0
                                        }

                                        Spacer()

                                        Button("New Playlist") {
                                            showingNewPlaylist = true
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                                .padding(.leading)
                                .buttonStyle(.borderless)
                            } else {
                                Text("Your Playlists")
                                    .font(.title3)
                                    .padding(.horizontal)
                            }
                        }

                        ForEach(collections) { collection in
                            PlaylistListItem(collection: collection)
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

                    ToolbarItem(placement: .topBarLeading) {
                        Button("New Playlist", systemImage: "plus") {
                            showingNewPlaylist = true
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
                .apply {
                    if #available(iOS 16, *) {
                        $0.alert("Create a Playlist", isPresented: $showingNewPlaylist) {
                            TextField("New Playlist Title", text: $newPlaylistTitle)

                            Button("Confirm", role: .confirmOrNil) {
                                Task {
                                    await model.createNewPlaylist(title: newPlaylistTitle)
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text(
                                "You will be able to add content to this playlist using the Save button while viewing content."
                            )
                        }
                    } else {
                        $0.sheet(isPresented: $showingNewPlaylist) {
                            VStack(spacing: 16) {
                                Text("Create a Playlist")
                                    .font(.title3)
                                    .padding(.bottom)

                                Text(
                                    "You will be able to add content to this playlist using the Save button while viewing content."
                                )

                                TextField("New Playlist Title", text: $newPlaylistTitle)
                                    .padding(.horizontal)

                                Button("Confirm") {
                                    Task {
                                        await model.createNewPlaylist(title: newPlaylistTitle)
                                    }

                                    showingNewPlaylist = false
                                }
                                .padding(.top)
                            }
                            .padding()
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
}

#Preview {
    PlaylistsScreen()
}
