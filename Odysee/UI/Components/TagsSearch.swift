//
//  TagsSearch.swift
//  Odysee
//
//  Created by Keith Toh on 11/05/2026.
//

import SwiftUI

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct TagsSearch: View {
    @State private var tags: [String] = ["a", "b", "c", "hello", "rld"]

    @State private var search: String = ""

    private var searchedTags: ArraySlice<String> {
        let searched = if search.isBlank {
            Constants.KnownTags
        } else {
            [search] + Constants.KnownTags.filter { $0.contains(search) }
        }

        return searched.prefix(5)
    }

    // FIXME: Handle comma (split into tags)
    var body: some View {
        Section("Tags") {
            Text("Selected Tags (\(5) left)")
                .bold()

            ForEach(tags) { tag in
                HStack {
                    Text(tag)

                    Button {
                        tags.removeAll(where: { $0 == tag })
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "xmark")
                        }
                    }
                }
            }

            TextField("Add Tags", text: $search, prompt: Text("Add Tags"))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit {
                    addTag(search.lowercased())
                }

            ForEach(searchedTags) { tag in
                HStack {
                    Text(tag)

                    Button {
                        addTag(tag)
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
    }

    private func addTag(_ tag: String) {
        tags.append(tag)
        search = ""
    }
}

#Preview {
    TagsSearch()
}
