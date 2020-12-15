//
//  RewardsViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 12/12/2020.
//

import Firebase
import SafariServices
import UIKit

class RewardsViewController: UIViewController {
    
    let discordLink = "https://discordapp.com/invite/Z3bERWA"
    
    @IBOutlet weak var closeVerificationButton: UIButton!
    @IBOutlet weak var twitterOptionButton: UIButton!
    @IBOutlet weak var skipQueueOptionButton: UIButton!
    @IBOutlet weak var manualOptionButton: UIButton!
    @IBOutlet weak var optionsScrollView: UIScrollView!
    
    @IBOutlet weak var rewardVerificationPathsView: UIView!
    @IBOutlet weak var mainRewardsView: UIView!
    
    // verification paths
    // 1 - phone verification?
    // 2 - twitter
    // 3 - iap
    // 4 - manual
    
    var verificationPath = 0
    
    override func viewWillAppear(_ animated: Bool) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
        
        if Lbryio.isSignedIn() {
            if !Lbryio.currentUser!.isRewardApproved! {
                showVerificationPaths()
            } else {
                showRewardsList()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Rewards", AnalyticsParameterScreenClass: "RewardsViewController"])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        
    }
    
    func showVerificationPaths() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        
        rewardVerificationPathsView.isHidden = false
        closeVerificationButton.isHidden = false
        mainRewardsView.isHidden = true
    }
    
    func showRewardsList() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: false)
        
        rewardVerificationPathsView.isHidden = true
        closeVerificationButton.isHidden = true
        mainRewardsView.isHidden = false
        
        // load the rewards list
        
    }
    
    var currentTag = 0
    
    @IBAction func optionButtonTapped(_ sender: UIButton!) {
        let currentTag = sender.tag
        let page = sender.tag - 100
        let optionButtons = [twitterOptionButton, skipQueueOptionButton, manualOptionButton]
        for button in optionButtons {
            button!.setTitleColor(UIColor.link, for: .normal)
        }
        if currentTag == sender.tag {
            sender.setTitleColor(Helper.primaryColor, for: .normal)
        }
        
        var frame: CGRect = optionsScrollView.frame
        frame.origin.x = frame.size.width * CGFloat(page)
        frame.origin.y = 0
        optionsScrollView.scrollRectToVisible(frame, animated: true)
    }
    
    @IBAction func manualActionTapped(_sender: UIButton) {
        if let url = URL(string: discordLink) {
            let vc = SFSafariViewController(url: url)
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            self.navigationController!.popViewController(animated: false)
            appDelegate.mainController.present(vc, animated: true, completion: nil)
        }
    }
    
    @IBAction func closeTapped(_sender: UIButton) {
        self.navigationController!.popViewController(animated: true)
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
