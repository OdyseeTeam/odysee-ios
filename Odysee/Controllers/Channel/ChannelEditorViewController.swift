//
//  ChannelEditorViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/12/2020.
//

import Firebase
import UIKit

class ChannelEditorViewController: UIViewController, UIGestureRecognizerDelegate {

    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    
    @IBOutlet weak var titleField: UITextField!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var depositField: UITextField!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var savingIndicator: UIActivityIndicatorView!
    
    var currentClaim: Claim? = nil
    var saveInProgress = false
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "ChannelForm", AnalyticsParameterScreenClass: "ChannelEditorViewController"])
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: false)
        
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        thumbnailImageView.rounded()
        populateFieldsForEdit()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func populateFieldsForEdit() {
        if currentClaim == nil {
            return
        }
        
        nameField.isEnabled = false
        titleField.text = currentClaim?.value!.title ?? ""
        nameField.text = currentClaim?.name!
        depositField.text = currentClaim?.amount!
    }
    
    @IBAction func saveTapped(_ sender: UIButton) {
        var name = nameField.text
        let deposit = Decimal(string: depositField.text!)
        
        if name != nil && !name!.starts(with: "@") {
            name = String(format: "@%@", name!)
        }
        
        // Why are Swift substrings so complicated?! name[1:] / name.substring(1), maybe?
        if name == nil || !LbryUri.isNameValid(String(name!.suffix(from: name!.index(name!.firstIndex(of: "@")!, offsetBy: 1)))) {
            showError(message: String.localized("Please enter a valid name for the channel"))
            return
        }
        if deposit == nil {
            showError(message: String.localized("Please enter a valid deposit amount"))
            return
        }
        if deposit! < Helper.minimumDeposit {
            showError(message: String(format: String.localized("The minimum allowed deposit amount is %@"),
                                      Helper.currencyFormatter4.string(for: Helper.minimumDeposit as NSDecimalNumber)!))
            return
        }
        let prevDeposit: Decimal? = currentClaim != nil ? Decimal(string: currentClaim!.amount!) : 0
        if Lbry.walletBalance == nil || deposit! - (prevDeposit ?? 0) > Lbry.walletBalance!.available! {
            showError(message: "Deposit cannot be higher than your wallet balance")
            return
        }
        
        let editMode = currentClaim != nil
        var options: Dictionary<String, Any> = [:]
        if !editMode {
            options["name"] = name
        } else {
            options["claim_id"] = currentClaim?.claimId
        }
        
        options["bid"] = Helper.sdkAmountFormatter.string(from: deposit! as NSDecimalNumber)!
        options["blocking"] = true
        if !(titleField.text ?? "").isBlank {
            options["title"] = titleField.text
        }
        
        saveInProgress = true
        savingIndicator.isHidden = false
        let method = editMode ? Lbry.methodChannelUpdate : Lbry.methodChannelCreate
        Lbry.apiCall(method: method, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                self.showError(error: error)
                
                self.saveInProgress = false
                self.checkControlStates()
                return
            }
            
            let result = data["result"] as? [String: Any]
            let outputs = result?["outputs"] as? [[String: Any]]
            if (outputs != nil) {
                outputs?.forEach{ item in
                    let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                    do {
                        let claimResult: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                        if (claimResult != nil && !editMode) {
                            self.logChannelCreate(claimResult!)
                        }
                    } catch let error {
                        print(error)
                    }
                }
                
                DispatchQueue.main.async {
                    self.showMessage(message: String.localized(editMode ? "The channel was successfully updated" : "The channel was successfully created"))
                     self.navigationController?.popViewController(animated: true)
                }
                return
            }
            
            self.showError(message: String.localized("An unknown error occurred. Please try again."))
        })
    }
    
    func logChannelCreate(_ claimResult: Claim) {
        
    }
        
    func checkControlStates() {
        DispatchQueue.main.async {
            if self.saveInProgress {
                self.cancelButton.isEnabled = false
                self.saveButton.isEnabled = false
                self.savingIndicator.isHidden = true
            } else {
                self.cancelButton.isEnabled = true
                self.saveButton.isEnabled = true
                self.savingIndicator.isHidden = false
            }
        }
    }
    
    @IBAction func backTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func showMessage(message: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showMessage(message: message)
    }
    func showError(message: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(message: message)
    }
    func showError(error: Error?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(error: error)
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
