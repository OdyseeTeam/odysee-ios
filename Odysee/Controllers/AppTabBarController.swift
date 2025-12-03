//
//  AppTabBarController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 12/11/2020.
//

import UIKit

class AppTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        AppDelegate.shared.mainTabViewController = self
        delegate = AppDelegate.shared

        let defaults = UserDefaults.standard
        if let lastIndex = defaults.value(forKey: AppDelegate.keyLastTabIndex) as? Int {
            selectedIndex = lastIndex
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
