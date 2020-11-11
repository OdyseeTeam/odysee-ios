//
//  InitViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import UIKit

class InitViewController: UIViewController {

    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let defaults = UserDefaults.standard
        Lbry.installationId = defaults.string(forKey: Lbry.keyInstallationId)
        if ((Lbry.installationId ?? "").isBlank) {
            Lbry.installationId = Lbry.generateId()
            defaults.set(Lbry.installationId, forKey: Lbry.keyInstallationId)
        }
        
        Lbryio.authToken = defaults.string(forKey: Lbryio.keyAuthToken)
        
        authenticateAndRegisterInstall()
    }
    
    func authenticateAndRegisterInstall() {
        do {
            try Lbryio.fetchCurrentUser(completion: { user, error in
                if (error != nil || user == nil) {
                    // show a startup error message
                    self.showError() // TODO: Show more meaningful errors for /user/me failures?
                    return
                }
                
                if (user != nil) {
                    self.registerInstall()
                }
            })
        } catch {
            // user/me failed
            // show eror message
            showError()
        }
    }
    
    func registerInstall() {
        do {
            try Lbryio.newInstall(completion: { error in
                if (error != nil) {
                    // show error
                    print(error!)
                    self.showError()
                    return
                }
                
                // successful authentication and install registration
                // open the main application interface
                DispatchQueue.main.async {
                    let main = self.storyboard?.instantiateViewController(identifier: "main_vc") as! UIViewController
                    main.modalPresentationStyle = .currentContext
                    self.present(main, animated: true)
                }
            })
        } catch {
            // install/new failed
            // show error message
            showError()
        }
    }
    
    func showError() {
        DispatchQueue.main.async {
            self.loadingIndicator.isHidden = true
            self.errorLabel.isHidden = false
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
