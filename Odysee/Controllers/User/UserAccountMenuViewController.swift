//
//  AccountMenuViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 09/12/2020.
//

import MessageUI
import SafariServices
import UIKit

class UserAccountMenuViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet var contentView: UIView!
    @IBOutlet var signUpLoginButton: UIButton!
    @IBOutlet var loggedInMenu: UIView!
    @IBOutlet var userEmailLabel: UILabel!
    @IBOutlet var signUpLoginContainer: UIView!

    @IBOutlet var goLiveLabel: UILabel!
    @IBOutlet var channelsLabel: UILabel!
    @IBOutlet var rewardsLabel: UILabel!
    @IBOutlet var invitesLabel: UILabel!
    @IBOutlet var deleteAccountLabel: UILabel!
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
        deleteAccountLabel.isHidden = !Lbryio.isSignedIn()
        signOutLabel.isHidden = !Lbryio.isSignedIn()

        if Lbryio.isSignedIn() {
            userEmailLabel.text = Lbryio.currentUser?.primaryEmail!
        }
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
        var handled = false
        if let user = Lbryio.currentUser {
            let to = "hello@odysee.com"
            let subject = String(format: "Request account deletion: %@", user.primaryEmail!)

            /*if MFMailComposeViewController.canSendMail() {
                let mc = MFMailComposeViewController()
                mc.setToRecipients([to])
                mc.setSubject(subject)

                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                if let mcDelegate = appDelegate.mainViewController as? MFMailComposeViewControllerDelegate {
                    mc.mailComposeDelegate = mcDelegate
                }

                appDelegate.mainViewController?.present(mc, animated: true)
                handled = true
            } else if let url = URL(string: String(
                format: "mailto:\(to)?subject=%@",
                subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            )) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    handled = true
                }
            }*/

            if !handled {
                let alert = UIAlertController(
                    title: String.localized("Delete Account"),
                    message: String
                        .localized("Please send an email to help@odysee.com requesting for your account to be deleted"),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: String.localized("OK"), style: .default, handler: { _ in
                    self.presentingViewController?.dismiss(animated: false, completion: nil)
                }))
                present(alert, animated: true)
            }
        }

        if handled {
            presentingViewController?.dismiss(animated: false, completion: nil)
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
