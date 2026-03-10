//
//  YouTubeSyncScreen+Setup.swift
//  Odysee
//
//  Created by Keith Toh on 24/02/2026.
//

import SwiftUI

extension YouTubeSyncScreen {
    struct Setup: View {
        static let returnUrl = "https://odysee.com/ytsync"

        var close: () -> Void
        @ObservedObject var model: YouTubeSyncScreen.ViewModel

        @State private var channel: String = ""
        @State private var language: String = {
            var languageKey = Locale.current.languageCode ?? ContentSources.languageCodeEN
            if let scriptCode = Locale.current.scriptCode {
                languageKey.append("-\(scriptCode)")
            }
            let regionCode = Locale.current.regionCode ?? ContentSources.regionCodeUS
            if languageKey != ContentSources.languageCodeEN, regionCode == ContentSources.regionCodeBR {
                languageKey.append("-\(regionCode)")
            }
            return languageKey
        }()

        @State private var agree: Bool = false

        private var valid: Bool {
            LbryUri.isNameValid(channel)
        }

        @FocusState private var channelFocused: Bool

        var body: some View {
            VStack(alignment: .leading) {
                Text("Sync your YouTube channel to Odysee")
                    .font(.title2)
                    .padding(.bottom)

                Text("Don't want to manually upload? Get your YouTube videos in front of the Odysee audience.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()
                    .padding(.vertical)

                if channel.isBlank || valid {
                    Text("Your desired Odysee channel name")
                } else {
                    Text("names cannot contain spaces or reserved symbols (?$#@;:/\\=\"<>%{}|^~[]`)")
                        .foregroundStyle(.red)
                }

                HStack {
                    Text("@")
                    TextField("channel", text: $channel)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($channelFocused)
                        .apply {
                            if agree {
                                $0.submitLabel(.done)
                            } else {
                                $0
                            }
                        }
                }
                .foregroundStyle(Color.accentColor)

                Text("Channel language")
                    .padding(.top, 20)

                Picker("Language", selection: $language) {
                    ForEach(Predefined.supportedLanguages) { language in
                        Text(language.name)
                    }
                }

                Toggle(isOn: $agree) {
                    Text(
                        "I want to sync my content to Odysee. I have also read and understand [how the program works](https://help.odysee.tv/category-syncprogram/limits/)."
                    )
                }
                .padding(.top, 20)

                Divider()
                    .padding(.vertical)

                HStack {
                    Button("Claim Now", action: submit)
                        .disabled(!(agree && valid))

                    Spacer()

                    Button("Skip", action: close)
                }

                Text(
                    "Enrollment in the Odysee Sync Program is based on a manual assessment which requires a channel to have at least 50,000 monthly views on YouTube, and to be in compliance with Odysee's [Community Guidelines](https://help.odysee.tv/communityguidelines/).\n[Learn more](https://help.odysee.tv/category-syncprogram/)."
                )
                .font(.caption)
                .padding(.top, 20)
            }
            .padding(.horizontal)
            .padding(.top)
            .onSubmit(submit)
        }

        private func submit() {
            guard valid else {
                channelFocused = true
                return
            }
            guard agree else {
                return
            }

            Task {
                do {
                    try await model.setup(channel: channel, language: language)
                } catch {
                    Helper.showError(error: error)
                }
            }
        }
    }
}

#Preview {
    YouTubeSyncScreen.Setup(
        close: {},
        model: .init()
    )
}
