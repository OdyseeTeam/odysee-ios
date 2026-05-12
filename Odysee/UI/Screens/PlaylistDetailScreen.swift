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

    @Environment(\.editMode) private var editMode
    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    @State private var editingDetails = false

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
                                    let count = collection.itemCount ?? collection.items.uris.count
                                    Text("\(Image(systemName: "play.square.stack")) \(count)")

                                    if collection.isPublic {
                                        Text("\(Image(systemName: "eye")) Public")
                                    } else {
                                        Text("\(Image(systemName: "lock")) Private")
                                    }

                                    Spacer()

                                    // TODO: Timezone check / conversion?
                                    // FIXME: onAppear
                                    let date = Date(timeIntervalSince1970: Double(collection.updatedAt))
                                    Text("Updated \(date.formatted(.relative(presentation: .numeric)))")
                                        .fixedSize(horizontal: false, vertical: true)
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
                        if collection.origin != .saved {
                            EditButton()
                        }

                        if isEditing {
                            Button("Details") {
                                editingDetails = true
                            }
                        }

                        Menu("More", systemImage: "ellipsis") {
                            Button("Copy") {}
                        }
                    }
                }
                .onChange(of: isEditing) { editing in
                    if !editing {
                        Task {
                            await model.saveChanges(collection: collection)
                        }
                    }
                }
                .sheet(isPresented: $editingDetails) {
                    PlaylistDetailForm(collection: collection) {
                        collection = $0
                    }
                    .environment(\.editMode, editMode)
                    .interactiveDismissDisabled()
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
