//
//  AccountMenuViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 09/12/2020.
//

import MessageUI
import SafariServices
import UIKit
import Odysee

class UserAccountMenuViewController: UIViewController, UIGestureRecognizerDelegate,
    UIPickerViewDataSource, UIPickerViewDelegate
{
    @IBOutlet var contentView: UIView!
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

    var defaultChannelPicker: UIPickerView!

    var channels: [Claim] = []

    let sweepWalletTarget = "bHg5cNFA8bF32CF6M8J3BndyZXqzreRjHz"
    let forfeitCreditsVerfication = String.localized("I forfeit my credits")
    let deleteAccountVerification = String.localized("I understand and I want to delete my account")

    override func viewDidLoad() {
        super.viewDidLoad()

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
            userEmailLabel.text = Lbryio.currentUser?.primaryEmail!
            loadChannels()
        }

        changeDefaultChannelButton.titleLabel?.textAlignment = .center
        changeDefaultChannelButton.titleLabel?.numberOfLines = 0
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == gestureRecognizer.view
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return channels.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return channels[row].name
    }

    @IBAction func anywhereTapped(_ sender: Any) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @IBAction func closeTapped(_ sender: UIButton) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @IBAction func signUpLoginTapped(_ sender: UIButton) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }

    @IBAction func goLiveTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "go_live_vc") as! GoLiveViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }

    @IBAction func channelsTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?
            .instantiateViewController(identifier: "channel_manager_vc") as! ChannelManagerViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }

    @IBAction func rewardsTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "rewards_vc") as! RewardsViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }

    @IBAction func signOutTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        presentingViewController?.dismiss(animated: false, completion: nil)
        appDelegate.mainController.stopAllTimers()
        appDelegate.mainController.resetUserAndViews()

        let initVc = storyboard?.instantiateViewController(identifier: "init_vc") as! InitViewController
        let window = view.window!
        window.rootViewController = initVc
        UIView.transition(
            with: window,
            duration: 0.2,
            options: .transitionCrossDissolve,
            animations: nil
        )
    }

    @IBAction func youTubeSyncTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        var vc: UIViewController!
        if Lbryio.Defaults.isYouTubeSyncConnected {
            vc = storyboard?
                .instantiateViewController(identifier: "yt_sync_status_vc") as! YouTubeSyncStatusViewController
        } else {
            vc = storyboard?.instantiateViewController(identifier: "yt_sync_vc") as! YouTubeSyncViewController
        }
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }

    @IBAction func communityGuidelinesTapped(_ sender: Any) {
        // https://odysee.com/@OdyseeHelp:b/Community-Guidelines:c
        if let url = LbryUri.tryParse(
            url: "https://odysee.com/@OdyseeHelp:b/Community-Guidelines:c",
            requireProto: false
        ) {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
            vc.claimUrl = url
            presentingViewController?.dismiss(animated: false, completion: nil)
            appDelegate.mainNavigationController?.view.layer.add(
                Helper.buildFileViewTransition(),
                forKey: kCATransition
            )
            appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
        }
    }

    @IBAction func helpAndSupportTapped(_ sender: Any) {
        // https://odysee.com/@OdyseeHelp:b?view=about
        if let url = LbryUri.tryParse(url: "https://odysee.com/@OdyseeHelp:b", requireProto: false) {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = storyboard?.instantiateViewController(withIdentifier: "channel_view_vc") as! ChannelViewController
            vc.claimUrl = url
            vc.page = 2
            presentingViewController?.dismiss(animated: false, completion: nil)
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func deleteAccountTapped(_ sender: Any) {
        if let _ = Lbryio.currentUser {
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
                    let response = alert.textFields![0].text
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
        let available = Lbry.walletBalance!.available! - 0.1

        var params = [String: Any]()
        params["addresses"] = [sweepWalletTarget]
        params["amount"] = Helper.sdkAmountFormatter.string(from: available as NSDecimalNumber)!
        params["blocking"] = true

        Lbry.apiCall(
            method: Lbry.methodWalletSend,
            params: params,
            connectionString: Lbry.lbrytvConnectionString,
            authToken: Lbryio.authToken,
            completion: { data, error in
                guard let _ = data, error == nil else {
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
            let response = alert.textFields![0].text
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
            method: Lbry.Methods.claimList,
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

        if #available(iOS 14.0, *) {
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
                for action in self.changeDefaultChannelButton.menu!.children {
                    (action as? UIAction)?.state = action == selected ? .on : .off
                }
            }
            let channelActions = channels.map { claim -> UIAction in
                let action = UIAction(
                    title: claim.name!,
                    identifier: .init(claim.claimId!),
                    handler: channelActionHandler
                )
                if claim.claimId == Lbry.defaultChannelId {
                    action.state = .on
                }
                return action
            }
            changeDefaultChannelButton.menu = UIMenu(title: "", children: channelActions)
            changeDefaultChannelButton.showsMenuAsPrimaryAction = true
        } else {
            changeDefaultChannelButton.addTarget(
                self, action: #selector(changeDefaultChannelTapped), for: .touchUpInside
            )
        }
    }

    @objc func changeDefaultChannelTapped(_ sender: Any) {
        let (picker, alert) = Helper.buildPickerActionSheet(
            title: "Change default channel",
            sourceView: changeDefaultChannelButton,
            dataSource: self,
            delegate: self,
            parent: self
        ) { _ in
            let index = self.defaultChannelPicker.selectedRow(inComponent: 0)
            Lbry.defaultChannelId = self.channels[index].claimId
            Lbry.saveSharedUserState { success, error in
                guard error == nil else {
                    self.showError(error: error)
                    return
                }
                if success {
                    Lbry.pushSyncWallet()
                }
            }
        }

        let index = channels.firstIndex { $0.claimId == Lbry.defaultChannelId } ?? 0
        picker.selectRow(index, inComponent: 0, animated: false)
        defaultChannelPicker = picker
        present(alert, animated: true, completion: nil)
    }

    func showError(message: String) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showError(message: message)
        }
    }

    func showError(error: Error?) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showError(error: error)
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
