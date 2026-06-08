//
//  PlaylistDetailForm.swift
//  Odysee
//
//  Created by Keith Toh on 08/05/2026.
//

import PhotosUI
import SwiftUI

struct PlaylistDetailForm: View {
    @State var collection: SharedPreference.Collection

    @State private var thumbnailUploadInProgress: Bool = false

    enum Mode {
        case publishing(publish: (SharedPreference.Collection) async -> Void)
        case edit(save: (SharedPreference.Collection) -> Void)
    }

    var mode: Mode

    private var publishing: Bool {
        if case .publishing = mode {
            true
        } else {
            false
        }
    }

    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.editMode) private var editMode

    private func sanitize(_ value: String) -> String {
        let range = NSRange(value.startIndex..., in: value)
        return LbryUri.regexInvalidUri.stringByReplacingMatches(
            in: value,
            options: [],
            range: range,
            withTemplate: "-"
        )
    }

    private func trim() {
        collection.name = collection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.title = collection.title?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationView {
            Form {
                if publishing || collection.isPublished {
                    Section("Name") {
                        if publishing {
                            ChannelPicker(channel: $collection.publishChannel.orElse(Claim.anonymous))
                        }

                        HStack {
                            let channel = collection.originalClaim?.signingChannel ?? collection.publishChannel
                            let slug = if channel != Claim.anonymous, let name = channel?.name {
                                name + "/"
                            } else {
                                ""
                            }
                            Text("odysee.com/\(slug)")
                                .font(.caption)
                            TextField("name", text: Binding {
                                sanitize(collection.name)
                            } set: {
                                collection.name = sanitize($0)
                            })
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        }

                        Text(
                            publishing ?
                                "This won't be able to be changed in the future." :
                                "This field cannot be changed."
                        )
                        .font(.footnote)
                    }
                    .disabled(!publishing)
                }

                Section("Title") {
                    TextField(
                        "Title",
                        text: publishing || collection.isPublished ?
                            $collection.title.orElse(collection.name) :
                            $collection.titleOrName
                    )
                }

                if #available(iOS 16, *) {
                    Section("Thumbnail (Optional)") {
                        ZStack {
                            ThumbnailPicker(
                                imageWidth: 320,
                                defaultImage: collection.thumbnail?.url,
                                inProgress: $thumbnailUploadInProgress
                            ) { url in
                                collection.thumbnail = .init(url: url)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Section("Description") {
                    TextEditor(text: $collection.description.orElse(""))

                    Text(
                        (try? AttributedString(markdown:
                            "Add formatting using Markdown syntax, or [Edit this playlist on the web](https://odysee.com/$/playlist/\(collection.collectionId)?view=edit) to add formatting interactively."
                        )) ?? "Add formatting using Markdown syntax"
                    )
                    .font(.caption)
                }

                TagsFormSection(tags: $collection.tags.orElse([]))
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Group {
                        switch mode {
                        case let .publishing(publish):
                            Button(collection.origin == .edited ? "Update" : "Publish") {
                                Task {
                                    trim()
                                    await publish(collection)
                                    dismiss()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        case let .edit(save):
                            Button("Save") {
                                trim()
                                save(collection)
                                dismiss()
                            }
                        }
                    }
                    .disabled(thumbnailUploadInProgress)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: dismiss)
                }
            }
        }
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
        editMode?.wrappedValue = .inactive
    }
}

#Preview {
    PlaylistDetailForm(collection: .init(
        id: "A",
        items: .init(uris: [
            LbryUri.tryParse(url: "lbry://@Odysee#8/FutureofOdyseeVideo#0", requireProto: true) ?? LbryUri(),
        ]),
        name: "named",
        type: .playlist,
        updatedAt: 1_776_134_690,
    ), mode: .edit(save: { _ in }))
}
