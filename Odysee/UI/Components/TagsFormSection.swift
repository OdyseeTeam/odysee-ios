//
//  TagsFormSection.swift
//  Odysee
//
//  Created by Keith Toh on 11/05/2026.
//

import SwiftUI

struct TagsFormSection: View {
    var limit: Int = 5

    @Binding var tags: [String]

    var controlTags: [Constants.ControlTags] = [.disableReactionsVideo, .disableSlimesVideo, .disableSupport]

    @State private var search: String = ""

    private var displayedTags: [String] {
        Array(Set(tags).subtracting(Constants.ControlTags.All)).sorted()
    }

    private var searchedTags: ArraySlice<String> {
        let searchTag = String(search.split(separator: ",").last ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let toSearch = Array(Set(Constants.KnownTags).subtracting(tags)).sorted()

        let searched = if searchTag.isBlank {
            toSearch
        } else {
            [searchTag] + toSearch.filter { $0 != searchTag && $0.contains(searchTag) }
        }

        return searched.prefix(limit)
    }

    var body: some View {
        Section("Tags") {
            Text("Selected Tags (\(limit - displayedTags.count) left)")
                .bold()
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(.h2)

            ForEach(displayedTags, id: \.self) { tag in
                HStack {
                    Text(tag)

                    Button {
                        tags.removeAll(where: { $0 == tag })
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: Icons.remove)
                        }
                    }
                    .accessibilityHint("Remove")
                }
                .accessibilityElement(children: .combine)
            }

            TextField("Add Tags", text: $search, prompt: Text("Add Tags"))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(submit)

            ForEach(searchedTags, id: \.self) { tag in
                HStack {
                    Text(tag)

                    Button {
                        addTag(tag)
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: Icons.add)
                        }
                    }
                    .disabled(
                        tag.starts(with: Constants.InternalTagPrefix) ||
                            Constants.ControlTags.All.contains(tag) ||
                            tags.contains(tag)
                    )
                    .accessibilityHint("Add")
                }
            }
            .disabled(displayedTags.count >= limit)
            .accessibilityElement(children: .combine)

            Text("User Interactions")
                .bold()
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(.h2)

            ForEach(controlTags) { tag in
                Toggle(tag.description, isOn: controlBinding(tag: tag.rawValue))
            }
        }
    }

    private func controlBinding(tag: String) -> Binding<Bool> {
        .init {
            tags.contains(tag)
        } set: { isOn in
            if isOn {
                if !tags.contains(tag) {
                    tags.append(tag)
                }
            } else {
                tags.removeAll { $0 == tag }
            }
        }
    }

    private func submit() {
        for tag in search.lowercased().split(separator: ",") {
            addTag(String(tag).trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func addTag(_ tag: String) {
        guard !tag.isEmpty,
              !tag.starts(with: Constants.InternalTagPrefix),
              !Constants.ControlTags.All.contains(tag),
              !tags.contains(tag)
        else {
            search = ""
            return
        }

        guard displayedTags.count < limit else {
            Helper.showMessage(message: __("Tag limit exceeded. Remove a selected tag first."))
            return
        }

        tags.append(tag)
        search = ""
    }
}

#Preview {
    Form {
        TagsFormSection(tags: Binding.constant(["a", "b", "c"]))
    }
}
