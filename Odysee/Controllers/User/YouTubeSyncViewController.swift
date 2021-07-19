//
//  YouTubeSyncViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/02/2021.
//

import Firebase
import UIKit
import WebKit

class YouTubeSyncViewController: UIViewController, WKNavigationDelegate {
    
    @IBOutlet weak var ytSyncScrollView: UIScrollView!
    @IBOutlet weak var claimNowButton: UIButton!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var youTubeSyncSwitch: UISwitch!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var channelNameField: UITextField!
    @IBOutlet weak var webView: WKWebView!
    
    let returnUrl = "https://odysee.com/ytsync"

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "YouTubeSync", AnalyticsParameterScreenClass: "YouTubeSyncViewController"])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        registerForKeyboardNotifications()
        webView.customUserAgent = "Version/8.0.2 Safari/600.2.5"
        webView.navigationDelegate = self
        claimNowButton.setTitleColor(UIColor.systemGray5, for: .disabled)
    }
    
    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let info = notification.userInfo
        let kbSize = (info![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.size
        let contentInsets = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: kbSize.height, right: 0.0)
        ytSyncScrollView.contentInset = contentInsets
        ytSyncScrollView.scrollIndicatorInsets = contentInsets
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        ytSyncScrollView.contentInset = contentInsets
        ytSyncScrollView.scrollIndicatorInsets = contentInsets
    }
    
    @IBAction func claimNowPressed(_ sender: UIButton) {
        var channelName = channelNameField.text ?? ""
        if youTubeSyncSwitch.isOn && channelName.isBlank {
            showError(message: String.localized("Please enter a channel name"))
            return
        }
        
        if !channelName.starts(with: "@") {
            channelName = String(format: "@%@", channelName)
        }
        if !LbryUri.isNameValid(String(channelName.suffix(from: channelName.index(channelName.firstIndex(of: "@")!, offsetBy: 1)))) {
            self.showError(message: String.localized("Please enter a valid name for the channel"))
            return
        }
        if Lbry.ownChannels.filter({ $0.name!.lowercased() == channelName.lowercased() }).first != nil {
            self.showError(message: String.localized("A channel with the specified name already exists"))
            return
        }
        
        claimNowButton.isHidden = true
        skipButton.isHidden = true
        loadingIndicator.isHidden = false
        
        do {
            let options: Dictionary<String, String> = [
                "type": "sync",
                "immediate_sync": "true",
                "desired_lbry_channel_name": channelName,
                "return_url": returnUrl
            ]
            try Lbryio.post(resource: "yt", action: "new", options: options, completion: { data, error in
                guard let data = data, error == nil else {
                    self.showError(error: error)
                    self.restoreButtons()
                    return
                }
                
                if let oauthUrl = data as? String {
                    if let url = URL(string: oauthUrl) {
                        DispatchQueue.main.async {
                            self.webView.isHidden = false
                            let request = URLRequest(url: url)
                            self.webView.load(request)
                        }
                            
                        return
                    }
                }
                
                // no valid url was returned
                self.restoreButtons()
                self.showError(message: "Unknown response. Please try again.")
            })
        } catch let error {
            self.showError(error: error)
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
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showError(error: error)
        }
    }
    
    func showError(message: String) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showError(message: message)
        }
    }
    
    func showMessage(message: String?) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showMessage(message: message)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let urlString = navigationAction.request.url?.absoluteString {
            if urlString.lowercased().starts(with: returnUrl.lowercased()) || urlString.lowercased() == returnUrl.lowercased() {
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
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainNavigationController?.popViewController(animated: true)
        if (ytSyncConnected) {
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
