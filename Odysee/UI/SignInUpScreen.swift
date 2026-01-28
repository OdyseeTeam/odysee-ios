//
//  SignInUpScreen.swift
//  Odysee
//
//  Created by Keith Toh on 27/01/2026.
//

import SwiftUI

struct SignInUpScreen: View {
    var close: () -> Void
    let closeRole = if #available(iOS 26, *) {
        ButtonRole.close
    } else {
        ButtonRole.cancel
    }

    var body: some View {
        ZStack {
            Text("Hello, World!")

            Button("Close", systemImage: "xmark", role: closeRole, action: close)
                .labelStyle(.iconOnly)
                .padding(.trailing)
                .padding(.top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .tint(.white)
        }
        .environment(\.colorScheme, .dark)
        .background {
            Image("ua_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
    }
}

#Preview {
    SignInUpScreen(close: {})
}
