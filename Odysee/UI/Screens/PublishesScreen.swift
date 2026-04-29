//
//  PublishesScreen.swift
//  Odysee
//
//  Created by Keith Toh on 31/03/2026.
//

import SwiftUI

struct PublishesScreen: View {
    @StateObject var model: ViewModel = .init()

    @State private var toDelete: Claim?

    var deleteConfirmText: String {
        if let title = toDelete?.titleOrName {
            __("Are you sure you'd like to remove \"\(title)\"?")
        } else {
            __("Are you sure you'd like to remove this claim?")
        }
    }

    var body: some View {
        GeometryReader { metrics in
            ZStack {
                List {
                    Group {
                        if !model.refreshing {
                            if model.claims.isEmpty {
                                VStack {
                                    Image("spaceman_sad")
                                        .resizable()
                                        .scaledToFit()
                                        // Image is roughly a square
                                        .frame(
                                            maxHeight: min(metrics.size.height / 2, metrics.size.width / 2),
                                            alignment: .center
                                        )
                                        .accessibilityHidden(true)

                                    Text("No uploads")

                                    Button("Upload Something New") {
                                        let vc = AppDelegate.shared.mainViewController?.storyboard?
                                            .instantiateViewController(
                                                identifier: "publish_vc"
                                            ) as! PublishViewController
                                        AppDelegate.shared.mainNavigationController?
                                            .pushViewController(vc, animated: true)
                                    }
                                    .foregroundColor(.accentColor)
                                }
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
                            .swipeActions(edge: .leading) {
                                Button {
                                    let vc = AppDelegate.shared.mainViewController?.storyboard?
                                        .instantiateViewController(identifier: "publish_vc") as! PublishViewController
                                    vc.currentClaim = claim
                                    AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions {
                                Button {
                                    toDelete = claim
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                // TODO: Make this an accessible destructive action, but without prematurely removing from the list
                                .tint(.red)
                            }
                        }
                        .confirmationDialog(
                            deleteConfirmText,
                            isPresented: $toDelete.bool,
                            titleVisibility: .visible
                        ) {
                            Button("Delete", role: .destructive) {
                                // Capture before confirmationDialog clears toDelete binding
                                if let toDelete {
                                    Task<Void, Never> {
                                        await model.delete(claim: toDelete)
                                    }
                                }
                            }
                        }

                        if model.inProgress || model.isLastPage {
                            Color.clear
                        } else {
                            Color.clear
                                .onAppear {
                                    Task<Void, Never> {
                                        await model.loadPage()
                                    }
                                }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init())
                }
                .listStyle(.plain)
                .refreshable(action: model.refresh)

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
    PublishesScreen()
}
