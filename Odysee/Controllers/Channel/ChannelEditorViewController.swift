//
//  ChannelEditorViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/12/2020.
//

import Firebase
import UIKit

class ChannelEditorViewController: UIViewController, UITextFieldDelegate, UIGestureRecognizerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var coverEditContainer: UIView!
    @IBOutlet weak var thumbnailEditContainer: UIView!
    
    @IBOutlet weak var titleField: UITextField!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var depositField: UITextField!
    @IBOutlet weak var descriptionField: UITextView!
    @IBOutlet weak var websiteField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    
    @IBOutlet weak var optionalFieldsContainer: UIView!
    @IBOutlet weak var toggleOptionalFieldsButton: UIButton!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var savingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var uploadingIndicator: UIView!
    
    var currentClaim: Claim? = nil
    var saveInProgress = false
    var nameFieldManualUpdate = false
    var selectingCover = false
    var selectingThumbnail = false
    var imageUploadInProgress = false
    var currentCoverUrl: String? = nil
    var currentThumbnailUrl: String? = nil
    
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
        coverEditContainer.layer.cornerRadius = 18
        thumbnailEditContainer.layer.cornerRadius = 18
        
        descriptionField.layer.borderColor = UIColor.systemGray5.cgColor
        descriptionField.layer.borderWidth = 1
        descriptionField.layer.cornerRadius = 4
        
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
        descriptionField.text = currentClaim?.value!.description ?? ""
        websiteField.text = currentClaim?.value!.websiteUrl ?? ""
        emailField.text = currentClaim?.value!.email ?? ""
    
        if currentClaim?.value!.cover != nil && !(currentClaim?.value!.cover!.url ?? "").isBlank {
            let coverUrl = currentClaim!.value!.cover!.url!
            coverImageView.load(url: URL(string: coverUrl)!)
        }
        if currentClaim?.value!.thumbnail != nil && !(currentClaim?.value!.thumbnail!.url ?? "").isBlank {
            let thumbnailUrl = currentClaim!.value!.thumbnail!.url!
            thumbnailImageView.backgroundColor = UIColor.clear
            thumbnailImageView.load(url: URL(string: thumbnailUrl)!)
        }
    }
    
    @IBAction func titleChanged(_ sender: UITextField) {
        let editMode = currentClaim != nil
        if !nameFieldManualUpdate && !editMode {
            let title = titleField.text!
            nameField.text = String(format: "@%@", title.replacingOccurrences(of: LbryUri.regexInvalidUri.pattern, with: "", options: .regularExpression)).lowercased()
        }
    }
    
    @IBAction func nameChanged(_ sender: UITextField) {
        nameFieldManualUpdate = true
    }
    
    @IBAction func saveTapped(_ sender: UIButton) {
        if saveInProgress {
            return
        }
        
        if imageUploadInProgress {
            showError(message: String.localized("Please wait for the pending image upload to finish"))
            return
        }
        
        var name = nameField.text
        let deposit = Decimal(string: depositField.text!)
        let editMode = currentClaim != nil
        
        if name != nil && !name!.starts(with: "@") {
            name = String(format: "@%@", name!)
        }
        
        // Why are Swift substrings so complicated?! name[1:] / name.substring(1), maybe?
        if name == nil || !LbryUri.isNameValid(String(name!.suffix(from: name!.index(name!.firstIndex(of: "@")!, offsetBy: 1)))) {
            showError(message: String.localized("Please enter a valid name for the channel"))
            return
        }
        if !editMode && Lbry.ownChannels.filter({ $0.name!.lowercased() == name?.lowercased() }).first != nil {
            showError(message: String.localized("A channel with the specified name already exists"))
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
        
        
        var options: Dictionary<String, Any> = [:]
        if !editMode {
            options["name"] = name
        } else {
            options["claim_id"] = currentClaim?.claimId
        }
        
        options["bid"] = Helper.sdkAmountFormatter.string(from: deposit! as NSDecimalNumber)!
        options["blocking"] = true
        
        if !(currentCoverUrl ?? "").isBlank {
            options["cover_url"] = currentCoverUrl!
        }
        if !(currentThumbnailUrl ?? "").isBlank {
            options["thumbnail_url"] = currentThumbnailUrl!
        }
        if !(titleField.text ?? "").isBlank {
            options["title"] = titleField.text
        }
        if !(descriptionField.text ?? "").isBlank {
            options["description"] = descriptionField.text
        }
        if !(websiteField.text ?? "").isBlank {
            options["website_url"] = websiteField.text
        }
        if !(emailField.text ?? "").isBlank {
            options["email"] = emailField.text
        }
        
        saveInProgress = true
        savingIndicator.isHidden = false
        toggleOptionalFieldsButton.isHidden = true
        checkControlStates()
        let method = editMode ? Lbry.methodChannelUpdate : Lbry.methodChannelCreate
        Lbry.apiCall(method: method, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                self.showError(error: error)
                self.saveInProgress = false
                self.checkControlStates()
                return
            }
            
            self.saveInProgress = false
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
            self.checkControlStates()
        })
    }
    
    func logChannelCreate(_ claimResult: Claim) {
        
    }
        
    func checkControlStates() {
        DispatchQueue.main.async {
            if self.saveInProgress {
                self.cancelButton.isEnabled = false
                self.saveButton.isEnabled = false
                self.savingIndicator.isHidden = false
                self.toggleOptionalFieldsButton.isHidden = true
            } else {
                self.cancelButton.isEnabled = true
                self.saveButton.isEnabled = true
                self.savingIndicator.isHidden = true
                self.toggleOptionalFieldsButton.isHidden = false
            }
        }
    }
    
    @IBAction func backTapped(_ sender: Any) {
        if saveInProgress {
            return
        }
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func coverImageTapped(_ sender: Any) {
        if imageUploadInProgress {
            showError(message: "Please wait for the pending image upload to finish")
            return
        }
        
        selectingCover = true
        selectingThumbnail = false
        showImagePicker()
    }
    
    @IBAction func thumbnailImageTapped(_ sender: Any) {
        if imageUploadInProgress {
            showError(message: "Please wait for the pending image upload to finish")
            return
        }
        
        selectingCover = false
        selectingThumbnail = true
        showImagePicker()
    }
    
    @IBAction func toggleOptionalFieldsTapped(_ sender: Any) {
        if optionalFieldsContainer.isHidden {
            optionalFieldsContainer.isHidden = false
            toggleOptionalFieldsButton.setTitle(String.localized("Hide optional fields"), for: .normal)
        } else {
            optionalFieldsContainer.isHidden = true
            toggleOptionalFieldsButton.setTitle(String.localized("Show optional fields"), for: .normal)
        }
    }
    
    func showImagePicker() {
        let pc = UIImagePickerController()
        pc.delegate = self
        pc.allowsEditing = true
        pc.mediaTypes = ["public.image"]
        pc.sourceType = .photoLibrary
        pc.modalPresentationStyle = .overCurrentContext
        present(pc, animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        selectingCover = false
        selectingThumbnail = false
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        // update the corresponding imageview
        guard let image = info[.editedImage] as? UIImage else {
            selectingCover = false
            selectingThumbnail = false
            return
        }
        
        if selectingCover {
            coverImageView.image = image
        } else if selectingThumbnail {
            thumbnailImageView.image = image
            thumbnailImageView.backgroundColor = UIColor.clear
        }
        
        // TODO: Upload the image data
        imageUploadInProgress = true
        uploadingIndicator.isHidden = false
        Helper.uploadImage(image: image, completion: { imageUrl, error in
            guard let imageUrl = imageUrl, error == nil else {
                DispatchQueue.main.async {
                    self.uploadingIndicator.isHidden = true
                }
                self.imageUploadInProgress = false
                self.showError(error: error)
                return
            }
            
            self.imageUploadInProgress = false
            DispatchQueue.main.async {
                self.uploadingIndicator.isHidden = true
            }
            
            if self.selectingCover {
                self.currentCoverUrl = imageUrl
            } else if self.selectingThumbnail {
                self.currentThumbnailUrl = imageUrl
            }
            
            self.selectingCover = false
            self.selectingThumbnail = false
        })
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func showMessage(message: String?) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showMessage(message: message)
        }
    }
    func showError(message: String?) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showError(message: message)
        }
    }
    func showError(error: Error?) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showError(error: error)
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
