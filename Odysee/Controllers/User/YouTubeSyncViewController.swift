//
//  YouTubeSyncViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/02/2021.
//

import FirebaseAnalytics
import UIKit
import WebKit

class YouTubeSyncViewController: UIViewController, WKNavigationDelegate {
    @IBOutlet var claimNowButton: UIButton!
    @IBOutlet var skipButton: UIButton!
    @IBOutlet var youTubeSyncSwitch: UISwitch!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet var channelNameField: UITextField!
    @IBOutlet var webView: WKWebView!

    let returnUrl = "https://odysee.com/ytsync"

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true)
        AppDelegate.shared.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "YouTubeSync",
                AnalyticsParameterScreenClass: "YouTubeSyncViewController",
            ]
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        webView.customUserAgent = "Version/8.0.2 Safari/600.2.5"
        webView.navigationDelegate = self
        claimNowButton.setTitleColor(UIColor.systemGray5, for: .disabled)
    }

    @IBAction func claimNowPressed(_ sender: UIButton) {
        var channelName = channelNameField.text ?? ""
        if youTubeSyncSwitch.isOn, channelName.isBlank {
            showError(message: String.localized("Please enter a channel name"))
            return
        }

        if !channelName.starts(with: "@") {
            channelName = "@\(channelName)"
        }
        // Name starts with @ from previous line
        if !LbryUri.isNameValid(String(channelName.dropFirst())) {
            showError(message: String.localized("Please enter a valid name for the channel"))
            return
        }

        if Lbry.ownChannels.filter({ $0.name?.lowercased() == channelName.lowercased() }).first != nil {
            showError(message: String.localized("A channel with the specified name already exists"))
            return
        }

        claimNowButton.isHidden = true
        skipButton.isHidden = true
        loadingIndicator.isHidden = false

        do {
            let options: [String: String] = [
                "type": "sync",
                "immediate_sync": "true",
                "desired_lbry_channel_name": channelName,
                "return_url": returnUrl,
            ]
            try Lbryio.post(resource: "yt", action: "new", options: options, completion: { data, error in
                guard let data = data, error == nil else {
                    self.showError(error: error)
                    self.restoreButtons()
                    return
                }

                if let oauthUrl = data as? String,
                   let url = URL(string: oauthUrl)
                {
                    DispatchQueue.main.async {
                        self.webView.isHidden = false
                        let request = URLRequest(url: url)
                        self.webView.load(request)
                    }

                    return
                }

                // no valid url was returned
                self.restoreButtons()
                self.showError(message: "Unknown response. Please try again.")
            })
        } catch {
            showError(error: error)
            restoreButtons()
        }
    }

    func restoreButtons() {
        DispatchQueue.main.async {
            self.claimNowButton.isHidden = false
            self.skipButton.isHidden = false
            self.loadingIndicator.isHidden = true
        }
    }

    @IBAction func skipPressed(_ sender: UIButton) {
        finishYouTubeSync(ytSyncConnected: false)
    }

    @IBAction func switchValueChanged(_ sender: UISwitch) {
        claimNowButton.isEnabled = sender.isOn
    }

    func showError(error: Error?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(error: error)
        }
    }

    func showError(message: String) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(message: message)
        }
    }

    func showMessage(message: String?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showMessage(message: message)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let urlString = navigationAction.request.url?.absoluteString {
            if urlString.lowercased().starts(with: returnUrl.lowercased()) || urlString.lowercased() == returnUrl
                .lowercased()
            {
                // successfully authorized, using the return url
                webView.isHidden = true
                decisionHandler(.cancel)
                finishYouTubeSync(ytSyncConnected: true)
                return
            }
        }

        decisionHandler(.allow)
    }

    func finishYouTubeSync(ytSyncConnected: Bool) {
        Lbryio.Defaults.isYouTubeSyncDone = true
        Lbryio.Defaults.isYouTubeSyncConnected = ytSyncConnected

        AppDelegate.shared.mainNavigationController?.popViewController(animated: true)
        if ytSyncConnected {
            // TODO: redirect to YouTube Sync Status page
        }
    }

    /*
     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
         // Get the new view controller using segue.destination.
         // Pass the selected object to the new view controller.
     }
     */
}
