//
//  YouTubeSyncScreen.swift
//  Odysee
//
//  Created by Keith Toh on 11/02/2026.
//

import SwiftUI
import WebKit

extension Optional {
    var bool: Bool {
        get {
            self != nil
        }
        set {
            if newValue == false {
                self = nil
            }
        }
    }
}

extension YouTubeSyncScreen {
    struct WebView: UIViewRepresentable {
        typealias UIViewType = WKWebView

        @Environment(\.dismiss) var dismiss

        @ObservedObject var model: YouTubeSyncScreen.ViewModel

        func makeUIView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.customUserAgent = "Mozilla/5.0 AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1"
            webView.navigationDelegate = context.coordinator
            webView.allowsBackForwardNavigationGestures = true
            return webView
        }

        func updateUIView(_ webView: WKWebView, context: Context) {
            if let url = model.setupOauthUrl {
                webView.load(URLRequest(url: url))
            }
        }

        class Coordinator: NSObject, WKNavigationDelegate {
            var parent: WebView

            init(_ parent: WebView) {
                self.parent = parent
            }

            func webView(
                _ webView: WKWebView,
                decidePolicyFor navigationAction: WKNavigationAction
            ) async -> WKNavigationActionPolicy {
                if let url = navigationAction.request.url,
                   url.absoluteString.lowercased().starts(with: Setup.returnUrl)
                {
                    do {
                        try parent.model.updateSetupReturnUrl(url)
                    } catch {
                        Helper.showError(error: error)
                    }

                    parent.dismiss()

                    return .cancel
                }

                return .allow
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
    }
}

struct YouTubeSyncScreen: View {
    var close: () -> Void
    @ObservedObject var model: ViewModel

    var body: some View {
        ZStack {
            GeometryReader { metrics in
                NavigationView {
                    ScrollView {
                        Group {
                            if model.showStatus {
                                Status(model: model)
                            } else {
                                Setup(
                                    close: close,
                                    model: model
                                )
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: metrics.size.height,
                            alignment: .top
                        )
                    }
                    .apply {
                        if #available(iOS 16.4, *) {
                            $0.scrollBounceBehavior(.basedOnSize)
                        } else {
                            $0
                        }
                    }
                }
                .navigationViewStyle(.stack)

                NavigationLink(isActive: $model.setupOauthUrl.bool) {
                    WebView(model: model)
                } label: {
                    EmptyView()
                }
                .hidden()
            }

            ProgressView()
                .controlSize(.large)
                .apply {
                    if model.inProgress {
                        $0
                    } else {
                        $0.hidden()
                    }
                }
        }
        .disabled(model.inProgress)
    }
}

#Preview {
    YouTubeSyncScreen(
        close: {},
        model: .init()
    )
}
