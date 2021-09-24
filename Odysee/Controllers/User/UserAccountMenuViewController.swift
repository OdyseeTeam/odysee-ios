//
//  AccountMenuViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 09/12/2020.
//

import SafariServices
import UIKit

class UserAccountMenuViewController: UIViewController {
    @IBOutlet var contentView: UIView!
    @IBOutlet var signUpLoginButton: UIButton!
    @IBOutlet var loggedInMenu: UIView!
    @IBOutlet var userEmailLabel: UILabel!
    @IBOutlet var signUpLoginContainer: UIView!

    @IBOutlet var goLiveLabel: UILabel!
    @IBOutlet var channelsLabel: UILabel!
    @IBOutlet var rewardsLabel: UILabel!
    @IBOutlet var invitesLabel: UILabel!
    @IBOutlet var signOutLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        contentView.layer.cornerRadius = 16
        signUpLoginButton.layer.cornerRadius = 16

        signUpLoginContainer.isHidden = Lbryio.isSignedIn()

        goLiveLabel.isHidden = !Lbryio.isSignedIn()
        userEmailLabel.isHidden = !Lbryio.isSignedIn()
        channelsLabel.isHidden = !Lbryio.isSignedIn()
        rewardsLabel.isHidden = !Lbryio.isSignedIn()
        // invitesLabel.isHidden = !Lbryio.isSignedIn()
        signOutLabel.isHidden = !Lbryio.isSignedIn()

        if Lbryio.isSignedIn() {
            userEmailLabel.text = Lbryio.currentUser?.primaryEmail!
        }
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
        // Open the web page for now until we support displaying text content

        // https://odysee.com/@OdyseeHelp:b/Community-Guidelines:c
        if let url = URL(string: "https://odysee.com/@OdyseeHelp:b/Community-Guidelines:c") {
            let vc = SFSafariViewController(url: url)
            presentingViewController?.dismiss(animated: false, completion: nil)
            AppDelegate.shared.mainController.present(vc, animated: true, completion: nil)
        }
    }

    @IBAction func helpAndSupportTapped(_ sender: Any) {
        // https://odysee.com/@OdyseeHelp:b?view=about
        if let url = URL(string: "https://odysee.com/@OdyseeHelp:b?view=about") {
            let vc = SFSafariViewController(url: url)
            presentingViewController?.dismiss(animated: false, completion: nil)
            AppDelegate.shared.mainController.present(vc, animated: true, completion: nil)
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
