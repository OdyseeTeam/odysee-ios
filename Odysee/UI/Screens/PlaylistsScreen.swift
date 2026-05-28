//
//  PlaylistsScreen.swift
//  Odysee
//
//  Created by Keith Toh on 09/04/2026.
//

import SwiftUI

struct PlaylistsScreen: View {
    @StateObject private var model: ViewModel = .init()

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

    @State private var toDelete: SharedPreference.Collection?

    var deleteConfirmText: String {
        if let title = toDelete?.titleOrName {
            __("Are you sure you'd like to delete \"\(title)\"?")
        } else {
            __("Are you sure you'd like to delete this playlist?")
        }
    }

    var unsaveConfirmText: String {
        if let title = toDelete?.titleOrName {
            __("Are you sure you'd like to unsave \"\(title)\"?")
        } else {
            __("Are you sure you'd like to unsave this playlist?")
        }
    }

    var collections: [SharedPreference.Collection] {
        if model.refreshing {
            return []
        }

        var published = model.publishedCollections

        for var edited in model.editedCollections {
            if let original = published[edited.collectionId] {
                edited.originalClaim = original.originalClaim
                published[edited.collectionId] = edited
            }
        }
        let publishedCollections = published.items

        let editedCollections = model.editedCollections.map {
            var collection = $0
            collection.originalClaim = published[collection.collectionId]?.originalClaim
            return collection
        }

        let all: [SharedPreference.Collection] = switch filterBy {
        case .all:
            model.unpublishedCollections + publishedCollections + model.savedCollections
        case .private:
            model.unpublishedCollections
        case .public:
            publishedCollections
        case .edited:
            editedCollections
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
            let compare: (Int, Int) -> Bool = sortAsc ? (<) : (>)

            let result = switch sortBy {
            case .name:
                $0.titleOrName.localizedCompare($1.titleOrName) == (sortAsc ? .orderedAscending : .orderedDescending)
            case .updated:
                compare($0.updatedAt, $1.updatedAt)
            case .videoCount:
                compare($0.count, $1.count)
            }

            return result
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
                                if filterBy == .all {
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
                                    Text("No matching playlists")
                                        .italic()
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            } else {
                                Text("Your Playlists")
                                    .font(.title3)
                                    .padding(.horizontal)
                            }
                        }

                        ForEach(collections) { collection in
                            PlaylistListItem(collection: collection)
                                .swipeActions {
                                    Button {
                                        toDelete = collection
                                    } label: {
                                        if collection.origin == .saved {
                                            Label("Unsave", systemImage: Icons.playlistUnsave)
                                        } else {
                                            Label("Delete", systemImage: Icons.delete)
                                        }
                                    }
                                    // TODO: Make this an accessible destructive action, but without prematurely removing from the list
                                    .tint(.red)
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
                        Menu("Sort", systemImage: Icons.sort) {
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
                                                systemImage: sortAsc ? Icons.ascending : Icons.descending
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
                        Menu("Filter", systemImage: Icons.filter) {
                            Picker("Filter By", selection: $filterBy) {
                                ForEach(FilterBy.allCases) { type in
                                    Text(type.rawValue.capitalized)
                                        .tag(type)
                                }
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        Button("New Playlist", systemImage: Icons.add) {
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
                    // TODO: Navigate to new playlist (NavigationView)
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
                                // FIXME: "You will be able to add content to this playlist using the Save button while viewing content."
                                "You will be able to add content to this playlist by long-pressing on videos (home/search results/recommended)"
                            )
                        }
                    } else {
                        $0.sheet(isPresented: $showingNewPlaylist) {
                            VStack(spacing: 16) {
                                Text("Create a Playlist")
                                    .font(.title3)
                                    .padding(.bottom)

                                Text(
                                    // FIXME: "You will be able to add content to this playlist using the Save button while viewing content."
                                    "You will be able to add content to this playlist by long-pressing on videos (home/search results/recommended)"
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
                .confirmationDialog(
                    toDelete?.origin == .saved ? unsaveConfirmText : deleteConfirmText,
                    isPresented: $toDelete.bool,
                    titleVisibility: .visible,
                    presenting: toDelete
                ) { toDelete in
                    if toDelete.isPublished {
                        Button("Delete (keep private playlist)", role: .destructive) {
                            model.delete(collection: toDelete, publishedKeepPrivate: true)
                        }
                    }

                    Button(toDelete.origin == .saved ? "Unsave" : "Delete", role: .destructive) {
                        model.delete(collection: toDelete)
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
        .environmentObject(model)
    }
}

#Preview {
    PlaylistsScreen()
}
