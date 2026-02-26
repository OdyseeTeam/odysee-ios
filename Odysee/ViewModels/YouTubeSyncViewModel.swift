//
//  YouTubeSyncViewModel.swift
//  Odysee
//
//  Created by Keith Toh on 11/02/2026.
//

import Foundation
import WebKit

extension YouTubeSyncScreen {
    @MainActor
    class ViewModel: NSObject, ObservableObject, WKNavigationDelegate {
        @Published private(set) var inProgress = false

        @Published var showStatus: Bool = false {
            didSet {
                if showStatus {
                    stopHasYoutubeChannelsWait()
                    startCheckYoutubeTransfers()
                } else {
                    stopCheckYoutubeTransfers()
                }
            }
        }

        @Published var setupOauthUrl: URL?
        @Published private(set) var setupReturnUrl: ReturnURL?

        @Published private(set) var channels: [AccountYoutubeChannel]? {
            didSet {
                if let channels {
                    showStatus = channels.count > 0
                }
            }
        }

        @Published private(set) var youtubeTransferStatus: (total: Int, complete: Int)?

        init(channels: [AccountYoutubeChannel]? = nil) {
            super.init()
            self.channels = channels
        }

        private func fetchUserChannels() async throws {
            let user = try await Lbryio.fetchCurrentUser()
            channels = user.youtubeChannels
        }

        // MARK: - Setup

        enum ReturnURL: Decodable, Equatable {
            /// <https://github.com/OdyseeTeam/internal-apis/blob/a3f181f/app/actions/youtube/onboard.go#L248>
            case success
            /// <https://github.com/OdyseeTeam/internal-apis/blob/a3f181f/app/actions/youtube/onboard.go#L502>
            case error(message: String)

            enum CodingKeys: String, CodingKey {
                case statusToken = "status_token"
                case error
                case errorMessage = "error_message"
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                if container.contains(.statusToken) {
                    self = .success
                    return
                }

                if (try? container.decode(String.self, forKey: .error)) == "true",
                   let message = try? container.decode(String.self, forKey: .errorMessage)
                {
                    self = .error(message: message)
                    return
                }

                throw GenericError("Invalid return URL query items")
            }
        }

        func setup(channel: String, language: String) async throws {
            inProgress = true
            defer {
                inProgress = false
            }

            let oauthUrl = try await AccountMethods.ytNew.call(params: .init(
                channelLanguage: language,
                desiredLbryChannelName: "@\(channel)",
            ))

            guard let url = URL(string: oauthUrl) else {
                throw GenericError("Invalid OAuth URL received")
            }

            setupOauthUrl = url
        }

        func updateSetupReturnUrl(_ url: URL) throws {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let query = components.queryItems
            else {
                throw GenericError("Invalid return URL received. Please try again.")
            }

            do {
                let returnUrl = try QueryItemsDecoder().decode(ReturnURL.self, from: query)
                setupReturnUrl = returnUrl
            } catch {
                throw GenericError("Error decoding return URL: \(error.localizedDescription). Please try again.")
            }

            if let setupReturnUrl {
                switch setupReturnUrl {
                case .success:
                    startHasYoutubeChannelsWait()
                case let .error(message):
                    throw GenericError(message)
                }
            }
        }

        static let channelsWaitInterval: UInt64 = 5_000_000_000 // 5 seconds
        private var hasYoutubeChannelsWait: Task<Void, Never>?

        private func startHasYoutubeChannelsWait() {
            guard Lbryio.isSignedIn(), hasYoutubeChannelsWait == nil else {
                return
            }

            hasYoutubeChannelsWait = Task {
                while true {
                    do {
                        // NOTE(discuss): Will immediately go to channels > 1 => Status when adding 2nd+ channel
                        try await fetchUserChannels()
                    } catch {
                        Helper.showError(error: error)
                    }

                    do {
                        try await Task.sleep(nanoseconds: Self.channelsWaitInterval)
                    } catch {
                        return
                    }
                }
            }
        }

        private func stopHasYoutubeChannelsWait() {
            hasYoutubeChannelsWait?.cancel()
            hasYoutubeChannelsWait = nil
        }

        // MARK: - Status

        private func fetchYoutubeTransferStatus() async throws {
            guard let channels, Self.hasPendingTransfers(channels: channels) else {
                return
            }

            let ytTransfer = try await AccountMethods.ytTransferStatusCheck.call(params: .init())

            let total = ytTransfer.reduce(0) { $0 + $1.totalPublishedVideos }
            let complete = ytTransfer.reduce(0) { $0 + $1.totalTransferred }

            youtubeTransferStatus = (total: total, complete: complete)
        }

        static let checkYoutubeTransfersInterval: UInt64 = 60_000_000_000 // 1 minute
        private var checkYoutubeTransfers: Task<Void, Never>?

        private func startCheckYoutubeTransfers() {
            guard Lbryio.isSignedIn(), checkYoutubeTransfers == nil else {
                return
            }

            checkYoutubeTransfers = Task {
                while true {
                    do {
                        try await fetchUserChannels()
                        try await fetchYoutubeTransferStatus()
                    } catch {
                        Helper.showError(error: error)
                    }

                    do {
                        try await Task.sleep(nanoseconds: Self.checkYoutubeTransfersInterval)
                    } catch {
                        return
                    }
                }
            }
        }

        private func stopCheckYoutubeTransfers() {
            checkYoutubeTransfers?.cancel()
            checkYoutubeTransfers = nil

            youtubeTransferStatus = nil
        }

        static func isNotElligible(channels: [AccountYoutubeChannel]) -> Bool {
            channels.count > 0 && channels.allSatisfy { $0.syncStatus == .abandoned }
        }

        static func isYoutubeTransferComplete(channels: [AccountYoutubeChannel]) -> Bool {
            channels.count > 0 && channels.allSatisfy {
                channels.count > 0 && $0.transferState == .completedTransfer || $0.syncStatus == .abandoned
            }
        }

        static func hasPendingTransfers(channels: [AccountYoutubeChannel]) -> Bool {
            channels.contains { $0.transferState == .pendingTransfer }
        }

        static func transferEnabled(channels: [AccountYoutubeChannel]) -> Bool {
            channels.contains(where: \.transferable)
        }

        func claimChannels() async throws {
            inProgress = true
            defer {
                inProgress = false
            }

            let addressList = try await BackendMethods.addressList.call(params: .init())

            guard let address = addressList.items.first else {
                throw GenericError("No (backend) wallet address found for this user")
            }

            let transfer = try await AccountMethods.ytTransfer.call(params: .init(
                address: address.address,
                publicKey: address.publicKey
            ))

            let channelCertificates = transfer.compactMap(\.channel?.channelCertificate)

            try await withThrowingTaskGroup { taskGroup in
                for certificate in channelCertificates {
                    taskGroup.addTask {
                        _ = try await BackendMethods.channelImport.call(params: .init(channelData: certificate))
                    }
                }

                try await taskGroup.waitForAll()
            }

            try await fetchUserChannels()
        }

        @Sendable func refreshStatus() async {
            await refreshStatus(indicateProgress: false)
        }

        func refreshStatus(indicateProgress: Bool) async {
            if indicateProgress {
                inProgress = true
            }
            defer {
                inProgress = false
            }

            do {
                try await fetchUserChannels()
                try await fetchYoutubeTransferStatus()
            } catch {
                Helper.showError(error: error)
            }
        }
    }
}
