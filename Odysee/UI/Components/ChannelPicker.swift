//
//  ChannelPicker.swift
//  Odysee
//
//  Created by Keith on 26/05/2026.
//

import SwiftUI

struct ChannelPicker: View {
    @Binding var channel: Claim

    @State private var channels: [Claim]?

    var body: some View {
        if let channels {
            Picker("Channel", selection: $channel) {
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

                            let channels = claimList.items.filter { $0.claimId != "anonymous" }
                            Lbry.ownChannels = channels

                            let defaultChannelId = await Wallet.shared.defaultChannelId
                            channel = channels.first { $0.claimId == defaultChannelId } ?? Claim.anonymous

                            self.channels = channels + [Claim.anonymous]
                        } catch {
                            Helper.showError(message: __("Error loading channels: \(error.localizedDescription)"))
                        }
                    }
                }
        }
    }
}

#Preview {
    ChannelPicker(channel: .constant(Claim.anonymous))
}
