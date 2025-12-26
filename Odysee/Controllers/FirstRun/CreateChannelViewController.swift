//
//  CreateChannelViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 15/03/2021.
//

import UIKit

class CreateChannelViewController: UIViewController, UITextFieldDelegate {
    var frDelegate: FirstRunDelegate?
    var firstRunFlow: Bool = false

    @IBOutlet var preloadView: UIView!
    @IBOutlet var scrollView: UIScrollView!

    @IBOutlet var channelNameField: UITextField!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!

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

        Lbry.apiCall(
            method: LbryMethods.claimList,
            params: .init(claimType: [.channel], page: 1, pageSize: 999)
        )
        .subscribeResult(didLoadChannels)
    }

    func didLoadChannels(_ result: Result<Page<Claim>, Error>) {
        guard case let .success(page) = result else {
            frDelegate?.requestFinished(showSkip: true, showContinue: false)
            return
        }

        if !page.items.isEmpty {
            // Channels already exist, no need to show the "Create First Channel" view
            frDelegate?.requestFinished(showSkip: true, showContinue: false)
            frDelegate?.nextStep()
        } else {
            frDelegate?.requestFinished(showSkip: true, showContinue: true)
            presentView()
        }
    }

    func presentView() {
        DispatchQueue.main.async {
            self.preloadView.isHidden = true
            self.scrollView.isHidden = false
            self.channelNameField.becomeFirstResponder()
        }
    }

    @IBAction func channelNameFieldChanged(_ sender: UITextField) {
        frDelegate?.updateFirstChannelName(sender.text)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if !textField.text.isBlank {
            frDelegate?.continueProcess()
        }
        return true
    }
}
