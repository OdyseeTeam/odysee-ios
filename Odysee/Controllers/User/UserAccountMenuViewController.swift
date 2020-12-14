//
//  AccountMenuViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 09/12/2020.
//

import UIKit

class UserAccountMenuViewController: UIViewController {

    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var signUpLoginButton: UIButton!
    @IBOutlet weak var loggedInMenu: UIView!
    @IBOutlet weak var userEmailLabel: UILabel!
    @IBOutlet weak var signUpLoginContainer: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        contentView.layer.cornerRadius = 16
        signUpLoginButton.layer.cornerRadius = 16
        
        
        signUpLoginContainer.isHidden = Lbryio.isSignedIn()
        
        userEmailLabel.isHidden = !Lbryio.isSignedIn()
        loggedInMenu.isHidden = !Lbryio.isSignedIn()
        
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

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
