//
//  NotificationsViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/12/2020.
//

import Firebase
import UIKit

class NotificationsViewController: UIViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.isHidden = !Lbryio.isSignedIn()
        
        if (!Lbryio.isSignedIn()) {
            // show the sign in view
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Notifications"])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
