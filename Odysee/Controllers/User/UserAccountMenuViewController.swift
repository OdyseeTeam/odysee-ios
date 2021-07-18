//
//  AccountMenuViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 09/12/2020.
//

import SafariServices
import UIKit

class UserAccountMenuViewController: UIViewController {

    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var signUpLoginButton: UIButton!
    @IBOutlet weak var loggedInMenu: UIView!
    @IBOutlet weak var userEmailLabel: UILabel!
    @IBOutlet weak var signUpLoginContainer: UIView!
    
    @IBOutlet weak var goLiveLabel: UILabel!
    @IBOutlet weak var channelsLabel: UILabel!
    @IBOutlet weak var rewardsLabel: UILabel!
    @IBOutlet weak var invitesLabel: UILabel!
    @IBOutlet weak var signOutLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        contentView.layer.cornerRadius = 16
        signUpLoginButton.layer.cornerRadius = 16
        
        signUpLoginContainer.isHidden = Lbryio.isSignedIn()
        
        goLiveLabel.isHidden =  !Lbryio.isSignedIn()
        userEmailLabel.isHidden = !Lbryio.isSignedIn()
        channelsLabel.isHidden = !Lbryio.isSignedIn()
        rewardsLabel.isHidden = !Lbryio.isSignedIn()
        //invitesLabel.isHidden = !Lbryio.isSignedIn()
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
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = self.storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }
    
    @IBAction func goLiveTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = self.storyboard?.instantiateViewController(identifier: "go_live_vc") as! GoLiveViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }
    
    @IBAction func channelsTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = self.storyboard?.instantiateViewController(identifier: "channel_manager_vc") as! ChannelManagerViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }
    
    @IBAction func rewardsTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = self.storyboard?.instantiateViewController(identifier: "rewards_vc") as! RewardsViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }
    
    @IBAction func signOutTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        presentingViewController?.dismiss(animated: false, completion: nil)
        appDelegate.mainController.stopAllTimers()
        appDelegate.mainController.resetUserAndViews()
        
        let initVc = storyboard?.instantiateViewController(identifier: "init_vc") as! InitViewController
        let window = self.view.window!
        window.rootViewController = initVc
        UIView.transition(with: window, duration: 0.2,
                          options: .transitionCrossDissolve, animations: nil)
    }
    
    @IBAction func youTubeSyncTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        var vc: UIViewController!
        if Lbryio.Defaults.isYouTubeSyncConnected {
            vc = self.storyboard?.instantiateViewController(identifier: "yt_sync_status_vc") as! YouTubeSyncStatusViewController
        } else {
            vc = self.storyboard?.instantiateViewController(identifier: "yt_sync_vc") as! YouTubeSyncViewController
        }
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        presentingViewController?.dismiss(animated: false, completion: nil)
    }
    
    @IBAction func communityGuidelinesTapped(_ sender: Any) {
        // Open the web page for now until we support displaying text content
        
        // https://odysee.com/@OdyseeHelp:b/Community-Guidelines:c
        if let url = URL(string: "https://odysee.com/@OdyseeHelp:b/Community-Guidelines:c") {
            let vc = SFSafariViewController(url: url)
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            presentingViewController?.dismiss(animated: false, completion: nil)
            appDelegate.mainController.present(vc, animated: true, completion: nil)
        }
    }
    
    @IBAction func helpAndSupportTapped(_ sender: Any) {
        // https://odysee.com/@OdyseeHelp:b?view=about
        if let url = URL(string: "https://odysee.com/@OdyseeHelp:b?view=about") {
            let vc = SFSafariViewController(url: url)
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            presentingViewController?.dismiss(animated: false, completion: nil)
            appDelegate.mainController.present(vc, animated: true, completion: nil)
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
