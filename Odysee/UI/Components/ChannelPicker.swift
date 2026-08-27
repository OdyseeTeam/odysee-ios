//
//  ChannelPicker.swift
//  Odysee
//
//  Created by Keith on 26/05/2026.
//

import SwiftUI

struct ChannelPicker: View {
    var title: LocalizedStringKey = "Channel"

    @Binding var channel: Claim

    var includeAnonymous: Bool = true

    @State private var channels: [Claim]?

    var body: some View {
        if let channels {
            Picker(title, selection: $channel) {
                ForEach(channels) {
                    Text($0.name ?? "")
                        .tag($0)
                }
            }
            .pickerStyle(.menu)
        } else {
            ProgressView()
                .onAppear {
                    Task {
                        do {
                            let claimList = try await BackendMethods.claimList.call(params: .init(
                                claimType: [.channel],
                                page: 1,
                                pageSize: 999,
                                resolve: true
                            ))

                            let channels = claimList.items.filter { $0.claimId != Claim.anonymous.claimId }
                            Lbry.ownChannels = channels

                            let defaultChannelId = Wallet.prefs.defaultChannelId
                            channel = channels.first { $0.claimId == defaultChannelId } ?? Claim.anonymous

                            if includeAnonymous {
                                self.channels = channels + [Claim.anonymous]
                            } else {
                                self.channels = channels
                            }
                        } catch {
                            Helper.showError(message: __("Error loading channels: \(error.localizedDescription)"))

                            if includeAnonymous {
                                channel = Claim.anonymous
                                channels = [channel]
                            }
                        }
                    }
                }
        }
    }
}

#Preview {
    ChannelPicker(channel: .constant(Claim.anonymous))
}
