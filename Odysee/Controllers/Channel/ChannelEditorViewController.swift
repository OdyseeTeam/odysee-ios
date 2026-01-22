//
//  ChannelEditorViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/12/2020.
//

import FirebaseAnalytics
import UIKit

class ChannelEditorViewController: UIViewController, UITextFieldDelegate, UIGestureRecognizerDelegate,
    UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    @IBOutlet var coverImageView: UIImageView!
    @IBOutlet var thumbnailImageView: UIImageView!
    @IBOutlet var coverEditContainer: UIView!
    @IBOutlet var thumbnailEditContainer: UIView!

    @IBOutlet var titleField: UITextField!
    @IBOutlet var nameField: UITextField!
    @IBOutlet var descriptionField: UITextView!
    @IBOutlet var websiteField: UITextField!
    @IBOutlet var emailField: UITextField!

    @IBOutlet var optionalFieldsContainer: UIView!
    @IBOutlet var toggleOptionalFieldsButton: UIButton!

    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var saveButton: UIButton!
    @IBOutlet var savingIndicator: UIActivityIndicatorView!
    @IBOutlet var uploadingIndicator: UIView!

    var currentClaim: Claim?
    var saveInProgress = false
    var nameFieldManualUpdate = false
    var selectingCover = false
    var selectingThumbnail = false
    var imageUploadInProgress = false
    var currentCoverUrl: String?
    var currentThumbnailUrl: String?
    var commentsVc: CommentsViewController!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true)
        AppDelegate.shared.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "ChannelForm",
                AnalyticsParameterScreenClass: "ChannelEditorViewController",
            ]
        )

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
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
        nameField.text = currentClaim?.name
        titleField.text = currentClaim?.value?.title
        nameField.text = currentClaim?.name
        descriptionField.text = currentClaim?.value?.description
        websiteField.text = currentClaim?.value?.websiteUrl
        emailField.text = currentClaim?.value?.email

        if let coverUrl = currentClaim?.value?.cover?.url,
           !coverUrl.isBlank,
           let url = URL(string: coverUrl)
        {
            coverImageView.load(url: url)
        }
        if let thumbnailUrl = currentClaim?.value?.thumbnail?.url,
           !thumbnailUrl.isBlank,
           let url = URL(string: thumbnailUrl)
        {
            thumbnailImageView.backgroundColor = UIColor.clear
            thumbnailImageView.load(url: url)
        }
    }

    @IBAction func titleChanged(_ sender: UITextField) {
        let editMode = currentClaim != nil
        if !nameFieldManualUpdate, !editMode, let title = titleField.text {
            nameField.text = String(
                format: "@%@",
                title.replacingOccurrences(of: LbryUri.regexInvalidUri.pattern, with: "", options: .regularExpression)
            ).lowercased()
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
        let deposit = Helper.minimumDeposit
        let editMode = currentClaim != nil

        if let name_ = name, !name_.starts(with: "@") {
            name = "@\(name_)"
        }
        // Name starts with @ from previous line
        guard let name, LbryUri.isNameValid(String(name.dropFirst())) else {
            showError(message: String.localized("Please enter a valid name for the channel"))
            return
        }

        if !editMode && Lbry.ownChannels.filter({ $0.name?.lowercased() == name.lowercased() }).first != nil {
            showError(message: String.localized("A channel with the specified name already exists"))
            return
        }

        let prevDeposit: Decimal = if let currentClaim,
                                      let amountString = currentClaim.amount,
                                      let amount = Decimal(string: amountString)
        {
            amount
        } else {
            0
        }
        if Lbry.walletBalance == nil || deposit - prevDeposit > Lbry.walletBalance?.available ?? 0 {
            showError(
                message: "Please try to claim some credits on odysee.com directly or reach out to hello@odysee.com to get more credits"
            )
            return
        }

        var options: [String: Any] = [:]
        if !editMode {
            options["name"] = name
        } else {
            options["claim_id"] = currentClaim?.claimId
        }

        options["bid"] = Helper.minimumDepositString
        options["blocking"] = true

        if let currentCoverUrl, !currentCoverUrl.isBlank {
            options["cover_url"] = currentCoverUrl
        }
        if let currentThumbnailUrl, !currentThumbnailUrl.isBlank {
            options["thumbnail_url"] = currentThumbnailUrl
        }
        if !titleField.text.isBlank {
            options["title"] = titleField.text
        }
        if !descriptionField.text.isBlank {
            options["description"] = descriptionField.text
        }
        if !websiteField.text.isBlank {
            options["website_url"] = websiteField.text
        }
        if !emailField.text.isBlank {
            options["email"] = emailField.text
        }

        saveInProgress = true
        savingIndicator.isHidden = false
        toggleOptionalFieldsButton.isHidden = true
        checkControlStates()
        let method = editMode ? Lbry.methodChannelUpdate : Lbry.methodChannelCreate
        Lbry.apiCall(
            method: method,
            params: options,
            url: Lbry.lbrytvURL,
            completion: { data, error in
                guard let data = data, error == nil else {
                    self.showError(error: error)
                    self.saveInProgress = false
                    self.checkControlStates()
                    return
                }

                self.saveInProgress = false
                let result = data["result"] as? [String: Any]
                let outputs = result?["outputs"] as? [[String: Any]]
                if outputs != nil {
                    outputs?.forEach { item in
                        do {
                            let data = try JSONSerialization.data(
                                withJSONObject: item,
                                options: [.prettyPrinted, .sortedKeys]
                            )
                            let claimResult: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                            if let claimResult, !editMode {
                                Lbryio.logPublishEvent(claimResult)
                            }
                        } catch {
                            print(error)
                        }
                    }

                    DispatchQueue.main.async {
                        self
                            .showMessage(
                                message: String
                                    .localized(
                                        editMode ? "The channel was successfully updated" :
                                            "The channel was successfully created"
                                    )
                            )
                        if let vc = self.commentsVc {
                            vc.loadChannels()
                        }
                        self.navigationController?.popViewController(animated: true)
                    }
                    return
                }

                self.showError(message: String.localized("An unknown error occurred. Please try again."))
                self.checkControlStates()
            }
        )
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
        navigationController?.popViewController(animated: true)
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

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
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
            AppDelegate.shared.mainController.showMessage(message: message)
        }
    }

    func showError(message: String?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(message: message)
        }
    }

    func showError(error: Error?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(error: error)
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
