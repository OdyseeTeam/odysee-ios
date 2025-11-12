//
//  LibraryViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/03/2021.
//

import Firebase
import UIKit

class LibraryViewController: UIViewController {
    @IBOutlet var viewContainer: UIView!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        view.isHidden = !Lbryio.isSignedIn()

        // check if current user is signed in
        if !Lbryio.isSignedIn() {
            // show the sign in view
            let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        showPublishesView()
        // Omly show publishes for now. In the future, allow the user to select between publishes / view history
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "Library",
                AnalyticsParameterScreenClass: "LibraryViewController",
            ]
        )
    }

    func showPublishesView() {
        let vc = storyboard?.instantiateViewController(identifier: "publishes_vc") as! PublishesViewController
        showViewController(vc)
    }

    func showViewController(_ vc: UIViewController) {
        for subview in viewContainer.subviews {
            subview.removeFromSuperview()
        }

        vc.willMove(toParent: self)
        viewContainer.addSubview(vc.view)
        vc.view.frame = CGRect(x: 0, y: 0, width: viewContainer.bounds.width, height: viewContainer.bounds.height)
        addChild(vc)
        vc.didMove(toParent: self)
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
