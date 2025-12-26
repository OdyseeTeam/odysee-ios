//
//  UserAccountMenuViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 09/12/2020.
//

import MessageUI
import SafariServices
import UIKit

class UserAccountMenuViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet var contentView: UIVisualEffectView!
    @IBOutlet var signUpLoginButton: UIButton!
    @IBOutlet var loggedInMenu: UIView!
    @IBOutlet var userEmailLabel: UILabel!
    @IBOutlet var signUpLoginContainer: UIView!

    @IBOutlet var changeDefaultChannelButton: UIButton!
    @IBOutlet var goLiveLabel: UILabel!
    @IBOutlet var channelsLabel: UILabel!
    @IBOutlet var rewardsLabel: UILabel!
    @IBOutlet var invitesLabel: UILabel!
    @IBOutlet var deleteAccountLabel: UILabel!
    @IBOutlet var signOutLabel: UILabel!

    var channels: [Claim] = []

    let sweepWalletTarget = "bHg5cNFA8bF32CF6M8J3BndyZXqzreRjHz"
    let forfeitCreditsVerfication = String.localized("I forfeit my credits")
    let deleteAccountVerification = String.localized("I understand and I want to delete my account")

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 26.0, *) {
            contentView.effect = UIGlassEffect(style: .regular)
        } else {
            contentView.effect = nil
            contentView.backgroundColor = .systemBackground
        }

        // Do any additional setup after loading the view.
        contentView.layer.cornerRadius = 16
        signUpLoginButton.layer.cornerRadius = 16

        signUpLoginContainer.isHidden = Lbryio.isSignedIn()

        changeDefaultChannelButton.isHidden = !Lbryio.isSignedIn()
        goLiveLabel.isHidden = !Lbryio.isSignedIn()
        userEmailLabel.isHidden = !Lbryio.isSignedIn()
        channelsLabel.isHidden = !Lbryio.isSignedIn()
        rewardsLabel.isHidden = !Lbryio.isSignedIn()
        // invitesLabel.isHidden = !Lbryio.isSignedIn()
        deleteAccountLabel.isHidden = !Lbryio.isSignedIn()
        signOutLabel.isHidden = !Lbryio.isSignedIn()

        if Lbryio.isSignedIn() {
            userEmailLabel.text = Lbryio.currentUser?.primaryEmail
            loadChannels()
        }

        changeDefaultChannelButton.titleLabel?.textAlignment = .center
        changeDefaultChannelButton.titleLabel?.numberOfLines = 0
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == gestureRecognizer.view
    }

    @IBAction func anywhereTapped(_ sender: Any) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @IBAction func closeTapped(_ sender: UIButton) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @IBAction func signUpLoginTapped(_ sender: UIButton) {
        let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }

    @IBAction func goLiveTapped(_ sender: Any) {
        let vc = storyboard?.instantiateViewController(identifier: "go_live_vc") as! GoLiveViewController
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }

    @IBAction func channelsTapped(_ sender: Any) {
        let vc = storyboard?
            .instantiateViewController(identifier: "channel_manager_vc") as! ChannelManagerViewController
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }

    @IBAction func rewardsTapped(_ sender: Any) {
        let vc = storyboard?.instantiateViewController(identifier: "rewards_vc") as! RewardsViewController
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }

    @IBAction func signOutTapped(_ sender: Any) {
        presentingViewController?.dismiss(animated: false, completion: nil)
        AppDelegate.shared.mainController.stopAllTimers()
        AppDelegate.shared.mainController.resetUserAndViews()

        let initVc = storyboard?.instantiateViewController(identifier: "init_vc") as! InitViewController
        if let window = view.window {
            window.rootViewController = initVc
            UIView.transition(
                with: window,
                duration: 0.2,
                options: .transitionCrossDissolve,
                animations: nil
            )
        }
    }

    @IBAction func youTubeSyncTapped(_ sender: Any) {
        var vc: UIViewController!
        if Lbryio.Defaults.isYouTubeSyncConnected {
            vc = storyboard?
                .instantiateViewController(identifier: "yt_sync_status_vc") as! YouTubeSyncStatusViewController
        } else {
            vc = storyboard?.instantiateViewController(identifier: "yt_sync_vc") as! YouTubeSyncViewController
        }
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }

    @IBAction func communityGuidelinesTapped(_ sender: Any) {
        if let url = URL(string: "https://help.odysee.tv/communityguidelines/") {
            let vc = SFSafariViewController(url: url)
            presentingViewController?.dismiss(animated: false, completion: nil)
            AppDelegate.shared.mainController.present(vc, animated: true, completion: nil)
        }
    }

    @IBAction func helpAndSupportTapped(_ sender: Any) {
        if let url = URL(string: "https://help.odysee.tv/") {
            let vc = SFSafariViewController(url: url)
            presentingViewController?.dismiss(animated: false, completion: nil)
            AppDelegate.shared.mainController.present(vc, animated: true, completion: nil)
        }
    }

    @IBAction func deleteAccountTapped(_ sender: Any) {
        if Lbryio.currentUser != nil {
            if !Lbry.ownChannels.isEmpty {
                let alert = UIAlertController(
                    title: String.localized("Delete Account: Delete your Channels"),
                    message: String
                        .localized(
                            "You still have content and / or channels in your account. In order to close it, you will need to remove these manually. Please return and take these actions before closing the account."
                        ),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: String.localized("OK"), style: .default, handler: { _ in
                    self.presentingViewController?.dismiss(animated: false, completion: nil)
                }))
                present(alert, animated: true)
                return
            }

            if let availableBalance = Lbry.walletBalance?.available, availableBalance > 1 {
                let alert = UIAlertController(
                    title: String.localized("Delete Account: Wallet Balance"),
                    message: String
                        .localized(
                            "You still have some credits in your account. You can either send these to a different account on the wallet page, or the credits will be returned to Odysee.\n\nIf you wish to forfeit these credits, please type 'I forfeit my credits' in the text field below"
                        ),
                    preferredStyle: .alert
                )
                alert.addTextField(configurationHandler: nil)
                alert.addAction(UIAlertAction(title: String.localized("Delete Anyway"), style: .default, handler: { _ in
                    guard let textFields = alert.textFields,
                          textFields.count > 0,
                          let response = textFields[0].text
                    else {
                        self.showError(message: String.localized("Failed to get text"))
                        return
                    }
                    if response != self.forfeitCreditsVerfication {
                        self.showError(message: String.localized("Please type the verification phrase to continue"))
                        self.deleteAccountTapped(UIButton())
                        return
                    }

                    // send out all credits if there are any
                    if availableBalance > 1 {
                        self.sweepCredits()
                        return
                    }

                    self.confirmDeleteAccount()
                }))
                alert
                    .addAction(UIAlertAction(
                        title: String.localized("Retrieve Credits"),
                        style: .cancel,
                        handler: { _ in
                            self.presentingViewController?.dismiss(animated: false, completion: nil)
                        }
                    ))
                present(alert, animated: true)
                return
            }

            confirmDeleteAccount()
        }
    }

    func sweepCredits() {
        if let available = Lbry.walletBalance?.available {
            let available = available - 0.1 // TODO: What if this goes below 0?

            var params = [String: Any]()
            params["addresses"] = [sweepWalletTarget]
            params["amount"] = Helper.sdkAmountFormatter.string(from: available as NSDecimalNumber) ?? "0"
            params["blocking"] = true

            Lbry.apiCall(
                method: Lbry.methodWalletSend,
                params: params,
                url: Lbry.lbrytvURL,
                completion: { data, error in
                    guard data != nil, error == nil else {
                        DispatchQueue.main.async {
                            self.showError(error: error)
                            self.deleteAccountTapped(UIButton())
                        }
                        return
                    }

                    DispatchQueue.main.async {
                        self.confirmDeleteAccount()
                    }
                }
            )
        }
    }

    func confirmDeleteAccount() {
        let alert = UIAlertController(
            title: String.localized("Confirm Delete Account"),
            message: String
                .localized(
                    "If you wish to delete your account, please type the phrase 'I understand and I want to delete my account' in the text field below."
                ),
            preferredStyle: .alert
        )
        alert.addTextField(configurationHandler: nil)
        alert.addAction(UIAlertAction(title: String.localized("Delete"), style: .default, handler: { _ in
            guard let textFields = alert.textFields,
                  textFields.count > 0,
                  let response = textFields[0].text
            else {
                self.showError(message: String.localized("Failed to get text"))
                return
            }
            if response != self.deleteAccountVerification {
                self.showError(message: String.localized("Please type the verification phrase to continue"))
                self.deleteAccountTapped(UIButton())
                return
            }

            self.didConfirmDeleteAccount()
        }))
        alert.addAction(UIAlertAction(title: String.localized("Cancel"), style: .cancel, handler: { _ in
            self.presentingViewController?.dismiss(animated: false, completion: nil)
        }))
        present(alert, animated: true)
    }

    func didConfirmDeleteAccount() {
        do {
            try Lbryio.get(resource: "user", action: "delete", options: [:], completion: { data, error in
                guard let data = data, error == nil else {
                    DispatchQueue.main.async {
                        self.showError(error: error)
                        self.deleteAccountTapped(UIButton())
                    }
                    return
                }
                if let result = data as? Bool, result {
                    // delete operation successfully completed
                    DispatchQueue.main.async {
                        self.presentingViewController?.dismiss(animated: false, completion: nil)
                        self.finishDeleteAccount()
                        return
                    }
                }

                // if we get to this stage, an error properly occurred
                DispatchQueue.main.async {
                    self
                        .showError(
                            message: String
                                .localized(
                                    "Your delete request could not be completed at this time. Please try again later."
                                )
                        )
                    self.deleteAccountTapped(UIButton())
                }
            })
        } catch {
            showError(
                message: String
                    .localized("An unknown error occurred with the delete request. Please try again later.")
            )
            deleteAccountTapped(UIButton())
        }
    }

    func finishDeleteAccount() {
        // sign out the user
        signOutTapped(UIButton())
    }

    func loadChannels() {
        Lbry.apiCall(
            method: BackendMethods.claimList,
            params: .init(claimType: [.channel], page: 1, pageSize: 999)
        )
        .subscribeResult(didLoadChannels)
    }

    func didLoadChannels(_ result: Result<Page<Claim>, Error>) {
        guard case let .success(page) = result else {
            result.showErrorIfPresent()
            return
        }

        channels = page.items

        let channelActionHandler: UIActionHandler = { selected in
            Lbry.defaultChannelId = selected.identifier.rawValue
            Lbry.saveSharedUserState { success, error in
                guard error == nil else {
                    self.showError(error: error)
                    return
                }
                if success {
                    Lbry.pushSyncWallet()
                }
            }
            if let menu = self.changeDefaultChannelButton.menu {
                for action in menu.children {
                    (action as? UIAction)?.state = action == selected ? .on : .off
                }
            }
        }
        let channelActions = channels.compactMap { claim -> UIAction? in
            if let name = claim.name, let claimId = claim.claimId {
                let action = UIAction(
                    title: name,
                    identifier: .init(claimId),
                    handler: channelActionHandler
                )
                if claim.claimId == Lbry.defaultChannelId {
                    action.state = .on
                }
                return action
            }
            return nil
        }
        changeDefaultChannelButton.menu = UIMenu(title: "", children: channelActions)
        changeDefaultChannelButton.showsMenuAsPrimaryAction = true
    }

    func showError(message: String) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(message: message)
        }
    }

    func showError(error: Error?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(error: error)
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
