//
//  PlaylistDetailScreen.swift
//  Odysee
//
//  Created by Keith Toh on 29/04/2026.
//

import SwiftUI
import WrappingHStack

struct PlaylistDetailScreen: View {
    @StateObject private var model: ViewModel = .init()

    @State var collection: SharedPreference.Collection

    var delete: ((SharedPreference.Collection) -> Void)?
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
                                    Text("\(Image(systemName: "play.square.stack")) \(collection.count)")

                                    if collection.isPublic {
                                        Text("\(Image(systemName: "eye")) Public")
                                    } else {
                                        Text("\(Image(systemName: "lock")) Private")
                                    }

                                    Spacer()

                                    // TODO: Timezone check / conversion?
                                    let date = Date(timeIntervalSince1970: Double(collection.updatedAt))
                                    Text("Updated \(date.formatted(.relative(presentation: .numeric)))")
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                            // FIXME: Long multiline channel text not leading

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
                        if [.builtin, .edited, .unpublished, .published].contains(collection.origin) {
                            EditButton()
                        }

                        if isEditing {
                            Button("Details") {
                                editingDetails = true
                                wasEditingDetails = true
                            }
                        } else {
                            Menu("More", systemImage: "ellipsis") {
                                if Wallet.isCollectionSaved(
                                    collection: collection,
                                    for: model.walletSavedCollectionIds
                                ) {
                                    Button("Unsave", systemImage: "minus.square") {
                                        Task {
                                            await Wallet.shared.removeSavedCollection(collection: collection)

                                            await Wallet.shared.queuePushSync()

                                            Helper.showMessage(message: "Playlist unsaved")
                                        }
                                    }
                                } else if collection.origin == .claim {
                                    Button("Save", systemImage: "plus.square") {
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

                                // FIXME: Test is it edited or published
                                // FIXME: collection.isPublishable
                                if [.unpublished, .edited].contains(collection.origin), collection.count > 0 {
                                    Button("Publish", systemImage: "icloud.and.arrow.up") {
                                        publishing = true
                                    }
                                }

                                Button("Copy", systemImage: "square.on.square") {
                                    showingCopy = true
                                }

                                if delete != nil && collection.origin == .unpublished {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        showingDelete = true
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
                    PlaylistDetailForm(collection: collection, mode: .publishing)
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

                                TextField("New Playlist Title", text: $newPlaylistTitle)
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
                .apply {
                    if let delete {
                        $0.confirmationDialog(
                            "Are you sure you'd like to delete \"\(collection.titleOrName)\"?",
                            isPresented: $showingDelete,
                            titleVisibility: .visible
                        ) {
                            Button("Delete", role: .destructive) {
                                delete(collection)
                            }
                        }
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
        ), delete: { _ in })
    }
}
