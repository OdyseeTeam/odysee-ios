//
//  FutureStreamsView.swift
//  Odysee
//
//  Created by Keith Toh on 10/10/2022.
//

import SwiftUI
import OrderedCollections

// MARK: Main View
struct FutureStreamsView: View {
    let futureClaims: OrderedSet<FutureClaimData>

    var body: some View {
        ScrollView(.horizontal) {
            if #available(iOS 14, *) {
                LazyHStack(spacing: 30) {
                    ForEach(futureClaims, id: \.claim.claimId) {
                        FutureStreamCard(claim: $0.claim, releaseTime: $0.releaseTime)
                    }
                }
            } else {
                HStack(spacing: 30) {
                    ForEach(futureClaims, id: \.claim.claimId) {
                        FutureStreamCard(claim: $0.claim, releaseTime: $0.releaseTime)
                    }
                }
            }
        }
    }
}

// MARK: Single card
struct FutureStreamCard: View {
    let claim: Claim
    let releaseTime: Date

    var body: some View {
        VStack {
            Text(claim.value?.title ?? claim.name ?? "N/A")
            if #available(iOS 14, *) {
                Text(releaseTime, style: .relative)
            }
            NetworkImage(
                url: claim.value?.thumbnail?.url.flatMap(URL.init)?.makeImageURL(
                    spec: ImageSpec(size: CGSize(width: 390, height: 220), format: "jpg")
                )
            )
            .frame(width: 100)
        }
        .frame(height: 100)
    }
}
