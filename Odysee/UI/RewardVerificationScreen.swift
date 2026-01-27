//
//  RewardVerificationScreen.swift
//  Odysee
//
//  Created by Keith Toh on 20/11/2025.
//

import SwiftUI

// https://stackoverflow.com/a/77735876
extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}

struct RewardVerificationScreen: View {
    var close: () -> Void

    @State private var verifyHeight = CGFloat.zero

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HStack {
                    Image("brand")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15 / 8 * 48, height: 48)
                }

                HStack {
                    Text("Verify to get ")
                        .font(.title)
                        .overlay(
                            GeometryReader { geometry in
                                Color.clear.onAppear {
                                    verifyHeight = geometry.frame(in: .local).size.height
                                }
                            }
                        )
                    Image("credits_icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: verifyHeight)
                }

                Text(
                    "Verified accounts are eligible to receive Credits for using Odysee. Verifying also helps us keep the Odysee community safe!"
                )
                .padding(.top)
                Text("This step is not mandatory and not required in order for you to use Odysee.")
                    .padding(.top, 1)
                    .font(.footnote)

                Spacer(minLength: 50)

                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "questionmark.circle")
                        .font(.headline)

                    VStack(alignment: .leading) {
                        Text("Verify via email")
                            .font(.title)

                        Text(
                            """
                            You can request verification of your Odysee account by sending an email to help@odysee.com
                            Verification requests can take a few hours to be approved.
                            """
                        )
                        .padding(.top, 1)
                    }
                    .padding(.leading, 10)
                }

                HStack {
                    VStack { Divider() }

                    Text("OR")
                        .font(.title)

                    VStack { Divider() }
                }
                .padding(.vertical)

                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "multiply")
                        .font(.headline)

                    VStack(alignment: .leading) {
                        Text("Skip")
                            .font(.title)

                        Text(
                            "Verifying is optional. If you skip this, it just means you can't receive Credits from our system."
                        )
                        .padding(.top, 1)

                        Button(action: close) {
                            Text("Continue Without Verifying")
                        }
                        .padding(.top, 1)
                    }
                    .padding(.leading, 10)
                }
            }
            .padding()
        }
        .apply {
            if #available(iOS 16.4, *) {
                $0.scrollBounceBehavior(.basedOnSize)
            } else {
                $0
            }
        }
    }
}

#Preview {
    RewardVerificationScreen(close: {})
}

@available(iOS 17, *)
#Preview(traits: .landscapeLeft) {
    RewardVerificationScreen(close: {})
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
