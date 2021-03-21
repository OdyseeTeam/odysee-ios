//
//  CreateChannelViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 15/03/2021.
//

import UIKit

class CreateChannelViewController: UIViewController {
    
    var frDelegate: FirstRunDelegate?
    var firstRunFlow: Bool = false
    
    @IBOutlet weak var preloadView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var channelNameField: UITextField!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        // load Channels, if the user already has channels, we'll move to the next step
        preloadView.isHidden = false
        scrollView.isHidden = true
        loadAndCheckChannels()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    func startLoading() {
        DispatchQueue.main.async {
            self.channelNameField.isEnabled = false
            self.loadingIndicator.isHidden = false
        }
    }
    
    func finishLoading() {
        DispatchQueue.main.async {
            self.channelNameField.isEnabled = true
            self.loadingIndicator.isHidden = true
        }
    }
    
    func loadAndCheckChannels() {
        frDelegate?.requestStarted()
        
        let options: Dictionary<String, Any> = ["claim_type": "channel", "page": 1, "page_size": 999, "resolve": false]
        Lbry.apiCall(method: Lbry.methodClaimList, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                self.frDelegate?.requestFinished(showSkip: true, showContinue: false)
                return
            }
            
            var numChannels = 0
            let result = data["result"] as? [String: Any]
            let items = result?["items"] as? [[String: Any]]
            if (items != nil) {
                numChannels = items?.count ?? 0
            }
            
            if numChannels > 0 {
                // Channels already exist, no need to show the "Create First Channel" view
                self.frDelegate?.requestFinished(showSkip: true, showContinue: false)
                self.frDelegate?.nextStep()
                return
            }
            
            self.frDelegate?.requestFinished(showSkip: true, showContinue: true)
            self.presentView()
        })
    }
    
    func presentView() {
        DispatchQueue.main.async {
            self.preloadView.isHidden = true
            self.scrollView.isHidden = false
            self.channelNameField.becomeFirstResponder()
        }
    }
    
    @IBAction func channelNameFieldChanged(_ sender: UITextField) {
        frDelegate?.updateFirstChannelName(sender.text!)
    }
}
