//
//  MainViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 11/11/2020.
//

import UIKit

class MainViewController: UIViewController {

    @IBOutlet weak var headerArea: UIView!
    @IBOutlet weak var headerAreaHeightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainViewController = self
        // Do any additional setup after loading the view.
    }
    
    // Experimental
    func toggleHeaderVisibility(hidden: Bool) {
        headerArea.isHidden = hidden
        headerAreaHeightConstraint.constant = hidden ? 0 : 52
        view!.layoutIfNeeded()
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
