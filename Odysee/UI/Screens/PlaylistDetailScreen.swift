//
//  PlaylistDetailScreen.swift
//  Odysee
//
//  Created by Keith Toh on 29/04/2026.
//

import SwiftUI

struct PlaylistDetailScreen: View {
    @StateObject private var model: ViewModel = .init()

    @State var collection: SharedPreference.Collection

    @Environment(\.editMode) private var editMode
    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    @State private var editingDetails = false

    var body: some View {
        GeometryReader { _ in
            ZStack {
                List {
                    Group {
                        if !model.refreshing {
                            VStack(alignment: .leading) {
                                if collection.isPublic,
                                   let publisher = collection.originalClaim?.signingChannel?.titleOrName
                                {
                                    Text(publisher)
                                        .font(.title3)
                                        // TODO: Accessibility test
                                        .accessibilityLabel(Text("Created by \(publisher)"))
                                }

                                if let description = collection.description {
                                    Text(
                                        (try? AttributedString(markdown: description)) ?? AttributedString(description)
                                    )
                                }

                                Spacer(minLength: 0)

                                HStack {
                                    let count = collection.itemCount ?? collection.items.uris.count
                                    Text("\(Image(systemName: "play.square.stack")) \(count)")

                                    if collection.isPublic {
                                        Text("\(Image(systemName: "eye")) Public")
                                    } else {
                                        Text("\(Image(systemName: "lock")) Private")
                                    }
                                }

                                let date = Date(timeIntervalSince1970: Double(collection.updatedAt))
                                // TODO: Timezone check / conversion?
                                // FIXME: onAppear
                                Text("Updated \(date.formatted(.relative(presentation: .numeric)))")
                            }

                            if model.claims.isEmpty {
                                Text("Nothing here")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }

                        ForEach(model.claims) { claim in
                            Button {
                                let vc = AppDelegate.shared.mainViewController?.storyboard?
                                    .instantiateViewController(identifier: "file_view_vc") as! FileViewController
                                vc.claim = claim

                                AppDelegate.shared.mainNavigationController?.view.layer.add(
                                    Helper.buildFileViewTransition(),
                                    forKey: kCATransition
                                )
                                AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: false)
                            } label: {
                                ClaimListItem(claim: claim)
                            }
                        }
                        .onMove(perform: model.move)
                        .onDelete(perform: model.delete)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init())
                }
                .listStyle(.plain)
                .navigationTitle(
                    isEditing ?
                        "Editing \(collection.titleOrName)" :
                        collection.titleOrName
                )
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
    PlaylistDetailScreen(collection: .init(
        id: "A",
        items: .init(uris: [
            LbryUri.tryParse(url: "lbry://@Odysee#8/FutureofOdyseeVideo#0", requireProto: true) ?? LbryUri(),
        ]),
        name: "named",
        type: .playlist,
        updatedAt: 1_776_134_690,
    ))
}
