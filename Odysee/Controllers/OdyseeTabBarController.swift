//
//  OdyseeTabBarController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 12/11/2020.
//

import UIKit

class AppTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
        var bottom = (tabBar.frame.size.height - (keyWindow!.safeAreaInsets.bottom ?? 34)) + 2
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: bottom)
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
