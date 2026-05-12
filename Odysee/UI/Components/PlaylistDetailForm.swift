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

    var save: (SharedPreference.Collection) -> Void

    @Environment(\.presentationMode) var presentationMode
    @Environment(\.editMode) var editMode

    var body: some View {
        NavigationView {
            Form {
                // FIXME: VoiceOver with field title in two places?
                Section("Title") {
                    TextField("Title", text: $collection.titleOrName)
                }

                if #available(iOS 16, *) {
                    Section("Thumbnail (Optional)") {
                        ZStack {
                            ThumbnailPicker(imageWidth: 320) { urlString in
                                collection.thumbnail = .init(url: URL(string: urlString))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Section("Description") {
                    Group {
                        TextEditor(text: $collection.description.orElse(""))
                    }

                    Text(
                        (try? AttributedString(markdown:
                            "Add formatting using Markdown syntax, or [Edit this playlist on the web](https://odysee.com/$/playlist/\(collection.collectionId)?view=edit) to add formatting interactively."
                        )) ?? "Add formatting using Markdown syntax"
                    )
                    .font(.caption)
                }

                // FIXME: (form/details) updated seems to update even with cancel
                TagsFormSection(tags: $collection.tags.orElse([]))
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        save(collection)
                        dismiss()
                    }
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
    ), save: { _ in })
}
