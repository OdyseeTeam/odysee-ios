//
//  ClaimFiltering.swift
//  Odysee
//
//  Created by Keith on 03/09/2026.
//

import Foundation

class ClaimFiltering: ObservableObject {
    static let shared = ClaimFiltering()

    static func reason(for claim: Claim) -> Reason? {
        shared.filteringReason(for: claim)
    }

    @Published private var appleBlockedClaimIds = FileListClaimIdsResult.ClaimIdsMap()
    @Published private var blockedClaimIds = FileListClaimIdsResult.ClaimIdsMap()
    @Published private var filteredClaimIds = FileListClaimIdsResult.ClaimIdsMap()

    @Published private var odyseeLocale: LocaleGetResult?
    @Published private var geoBlockedRules = GeoBlockedListResult.Rules()

    // FIXME: If fails to load, fail open or closed?
    // At the moment is fail open (all content allowed)
    private init() {
        Task {
            do {
                try await loadAll()
            } catch {
                await Helper.showError(error: error)
            }
        }
    }

    private func loadAll() async throws {
        appleBlockedClaimIds = try await AccountMethods.listAppleBlockedClaimIds.call(
            params: .init(), authTokenOverride: ""
        ).claimIds
        blockedClaimIds = try await AccountMethods.listBlockedClaimIds.call(
            params: .init(), authTokenOverride: ""
        ).claimIds
        filteredClaimIds = try await AccountMethods.listFilteredClaimIds.call(
            params: .init(), authTokenOverride: ""
        ).claimIds

        // FIXME: Doc: allow not getting locale, means geo blocked will be always blocked?
        odyseeLocale = try? await AccountMethods.localeGet.call(params: .init())
        geoBlockedRules = try await AccountMethods.geoBlockedList.call(
            params: .init(), authTokenOverride: ""
        ).rules
    }

    enum Reason {
        case appleBlocked(message: String)
        case blocked(message: String)
        case filtered(message: String)
        case geoBlocked(rule: GeoBlockedListResult.Rule)

        var message: String {
            switch self {
            case let .appleBlocked(message):
                message
            case let .blocked(message):
                message
            case let .filtered(message):
                message
            case let .geoBlocked(rule):
                rule.message ?? "Claim is geoblocked"
            }
        }
    }

    private func filteringReason(for claim: Claim) -> Reason? {
        let id = claim.id
        let channelId = claim.signingChannel?.id

        if let tag = appleBlockedClaimIds[id] ?? appleBlockedClaimIds[channelId] {
            return .appleBlocked(message: message(for: tag))
        }

        if let tag = blockedClaimIds[id] ?? blockedClaimIds[channelId] {
            return .blocked(message: message(for: tag))
        }

        if let tag = filteredClaimIds[id] ?? filteredClaimIds[channelId] {
            return .filtered(message: message(for: tag))
        }

        if let rules = geoBlockedRules[id] ?? geoBlockedRules[channelId] {
            // Block for everyone if locale isn't available
            guard let odyseeLocale else {
                return .geoBlocked(rule: .localeUnknown)
            }

            if let rule = rules.first(where: { rule in
                switch rule.scope {
                case .country:
                    rule.id.caseInsensitiveCompare(odyseeLocale.country) == .orderedSame
                case .continent:
                    rule.id.caseInsensitiveCompare(odyseeLocale.continent) == .orderedSame
                case .special:
                    odyseeLocale.isEUMember && rule.id.caseInsensitiveCompare("eu-only") == .orderedSame
                }
            }) {
                return .geoBlocked(rule: rule)
            }
        }

        return nil
    }

    private func message(for tag: FileListClaimIdsResult.Tag) -> String {
        switch tag {
        case "dmca",
             "internal-dmca-redflag":
            "In response to a complaint we received under the US Digital Millennium Copyright Act, we have blocked access to this content from our applications."
        case "filter-ios":
            "This content is not available on iOS. Consider using odysee.com for the Complete Odysee Experience."
        default:
            "This content violates the terms and conditions of Odysee and has been filtered."
        }
    }
}
