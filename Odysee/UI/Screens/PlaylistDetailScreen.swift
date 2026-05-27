//
//  PlaylistDetailScreen.swift
//  Odysee
//
//  Created by Keith Toh on 29/04/2026.
//

import SwiftUI
import WrappingHStack

// FIXME: Add button to play playlist from here
struct PlaylistDetailScreen: View {
    @StateObject private var model: ViewModel = .init()
    @EnvironmentObject private var playlistsModel: PlaylistsScreen.ViewModel

    @State var collection: SharedPreference.Collection

    var onCopy: (() -> Void)?

    @Environment(\.editMode) private var editMode
    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    @Environment(\.dismiss) var dismiss

    @State private var updatedAt: String = ""

    @State private var editingDetails = false
    /// If edit was for details, don't save changes on Cancel
    @State private var wasEditingDetails = false
    @State private var editingDetailsSave = false

    @State private var publishing = false

    @State private var showingCopy = false
    @State private var newPlaylistTitle = ""

    @State private var showingCancelUpdates = false

    @State private var showingDelete = false

    // FIXME: Accessbility
    var body: some View {
        GeometryReader { _ in
            ZStack {
                List {
                    Group {
                        if !model.refreshing {
                            VStack(alignment: .leading, spacing: 8) {
                                if collection.isPublic,
                                   let channel = collection.originalClaim?.signingChannel,
                                   let publisher = channel.titleOrName
                                {
                                    Button {
                                        Helper.openChannelVc(channel)
                                    } label: {
                                        Text(publisher)
                                            .accessibilityLabel("Created by \(publisher)")
                                    }
                                    .buttonStyle(.borderless)
                                }

                                if let description = collection.description {
                                    Text(
                                        (try? AttributedString(markdown: description)) ?? AttributedString(description)
                                    )
                                }

                                WrappingHStack(spacing: .dynamic(minSpacing: 0), lineSpacing: 8) {
                                    Text("\(Image(systemName: Icons.claimCollection)) \(collection.count)")

                                    if collection.isPublic {
                                        Text("\(Image(systemName: Icons.public)) Public")
                                    } else {
                                        Text("\(Image(systemName: Icons.private)) Private")
                                    }

                                    Spacer()

                                    if collection.updatedAt > 0 {
                                        // TODO: Timezone check / conversion?
                                        let date = Date(timeIntervalSince1970: Double(collection.updatedAt))
                                            .addingTimeInterval(-1)
                                        Text("Updated \(date.formatted(.relative(presentation: .numeric)))")
                                            .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        Text("Pending")
                                    }
                                }

                                if collection.origin == .edited {
                                    WrappingHStack(spacing: .dynamic(minSpacing: 0), lineSpacing: 8) {
                                        Button("Publish Updates", systemImage: Icons.publish) {
                                            publishing = true
                                        }

                                        Button("Clear Updates", systemImage: Icons.playlistClearUpdates) {
                                            showingCancelUpdates = true
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                    .padding(.top)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 32)

                            if !model.inProgress && model.claims.isEmpty {
                                Text("Nothing here")
                                    .italic()
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        ForEach(model.claims) { claim in
                            ClaimListItem(claim: claim)
                        }
                        .onMove(perform: model.move)
                        .onDelete(perform: model.delete)
                        .deleteDisabled(!isEditing) // Disable delete swipe action
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init())
                }
                .listStyle(.plain)
                .navigationTitle(
                    // TODO: Try to use Binding for rename action
                    isEditing ?
                        "Editing \(collection.titleOrName)" :
                        collection.titleOrName
                )
                .navigationBarTitleDisplayMode(.inline)
                .task {
                    do {
                        try await model.loadClaims(collection: collection)
                    } catch {
                        Helper.showError(error: error)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if collection.canEdit {
                            EditButton()
                        }

                        if isEditing {
                            Button("Details") {
                                editingDetails = true
                                wasEditingDetails = true
                            }
                        } else {
                            Menu("More", systemImage: Icons.more) {
                                if Wallet.isCollectionSaved(
                                    collection: collection,
                                    for: model.walletSavedCollectionIds
                                ) {
                                    Button("Unsave", systemImage: Icons.playlistUnsave, role: .destructive) {
                                        Task {
                                            await Wallet.shared.removeSavedCollection(collection: collection)

                                            await Wallet.shared.queuePushSync()

                                            Helper.showMessage(message: "Playlist unsaved")
                                        }
                                    }
                                } else if collection.origin == .claim {
                                    Button("Save", systemImage: Icons.playlistSave) {
                                        Task {
                                            await Wallet.shared.addSavedCollection(collection: collection)

                                            await Wallet.shared.queuePushSync()

                                            Helper
                                                .showMessage(
                                                    message: "Playlist saved. You can find it in Library -> Playlists"
                                                )
                                        }
                                    }
                                }

                                if collection.origin == .unpublished {
                                    Button("Publish", systemImage: Icons.publish) {
                                        publishing = true
                                    }
                                }

                                Button("Copy", systemImage: Icons.copy) {
                                    newPlaylistTitle = "\(collection.titleOrName) (copy)"
                                    showingCopy = true
                                }

                                if collection.canDelete {
                                    Button(role: .destructive) {
                                        showingDelete = true
                                    } label: {
                                        if collection.origin == .saved {
                                            Label("Unsave", systemImage: Icons.playlistUnsave)
                                        } else {
                                            Label("Delete", systemImage: Icons.delete)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .onChange(of: isEditing) { editing in
                    if !editing {
                        if !wasEditingDetails || editingDetailsSave {
                            Task {
                                collection = await model.saveChanges(collection: collection)

                                let date = Date(timeIntervalSince1970: Double(collection.updatedAt))
                                    .addingTimeInterval(-1)
                                updatedAt = date.formatted(.relative(presentation: .numeric))
                            }
                        }

                        wasEditingDetails = false
                        editingDetailsSave = false
                    }
                }
                .sheet(isPresented: $editingDetails) {
                    PlaylistDetailForm(collection: collection, mode: .edit(save: {
                        editingDetailsSave = true
                        collection = $0
                    }))
                    .environment(\.editMode, editMode)
                    .interactiveDismissDisabled()
                }
                .sheet(isPresented: $publishing) {
                    PlaylistDetailForm(collection: collection, mode: .publishing(publish: { collection in
                        await model.publish(collection: collection)
                        do {
                            try await playlistsModel.collectionListAll()
                        } catch {
                            Helper.showError(error: error)
                        }
                    }))
                    .interactiveDismissDisabled()
                }
                .apply {
                    if #available(iOS 16, *) {
                        $0.alert("Copy Playlist", isPresented: $showingCopy) {
                            TextField("New Playlist Title", text: $newPlaylistTitle)

                            Button("Confirm", role: .confirmOrNil, action: copy)
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text(
                                "The copied playlist will be private and you will be able to edit its contents at any time."
                            )
                        }
                    } else {
                        $0.sheet(isPresented: $showingCopy) {
                            VStack(spacing: 16) {
                                Text("Copy Playlist")
                                    .font(.title3)
                                    .padding(.bottom)

                                Text(
                                    "The copied playlist will be private and you will be able to edit its contents at any time."
                                )

                                TextField("New Playlist Title", text: $newPlaylistTitle,)
                                    .padding(.horizontal)

                                Button("Confirm") {
                                    copy()

                                    showingCopy = false
                                }
                                .padding(.top)
                            }
                            .padding()
                        }
                    }
                }
                .confirmationDialog(
                    "Clear all local edits from this published playlist?",
                    isPresented: $showingCancelUpdates,
                    titleVisibility: .visible
                ) {
                    Button("Clear Updates", role: .destructive) {
                        Task {
                            await Wallet.shared.removeEdited(collection: collection)

                            await Wallet.shared.queuePushSync()

                            Helper.showMessage(message: "Updates cleared")
                            // NOTE: View dismisses due to list item with NavigationLink being removed
                            // TODO: Stay in the view with proper programmatic navigation
                        }
                    }
                } message: {
                    Text("You won't be able to undo this action later.")
                }
                .confirmationDialog(
                    collection.origin == .saved ?
                        "Are you sure you'd like to unsave \"\(collection.titleOrName)\"?" :
                        "Are you sure you'd like to delete \"\(collection.titleOrName)\"?",
                    isPresented: $showingDelete,
                    titleVisibility: .visible
                ) {
                    if collection.isPublished {
                        Button("Delete (keep private playlist)", role: .destructive) {
                            playlistsModel.delete(collection: collection, publishedKeepPrivate: true)
                            dismiss()
                        }
                    }

                    Button(collection.origin == .saved ? "Unsave" : "Delete", role: .destructive) {
                        playlistsModel.delete(collection: collection)
                        dismiss()
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

    private func copy() {
        Task {
            await model.copy(collection: collection, title: newPlaylistTitle)
            dismiss()

            onCopy?()

            // TODO: Navigate to new playlist (NavigationView)
        }
    }
}

#Preview {
    NavigationView {
        PlaylistDetailScreen(collection: .init(
            id: "A",
            items: .init(uris: [
                LbryUri.tryParse(url: "lbry://@Odysee#8/FutureofOdyseeVideo#0", requireProto: true) ?? LbryUri(),
            ]),
            name: "named",
            description: "A playlist",
            type: .playlist,
            updatedAt: 1_776_134_690,
        ))
    }
}
