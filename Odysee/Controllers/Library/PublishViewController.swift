//
//  PublishViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 26/02/2021.
//

import MobileCoreServices
import Firebase
import Photos
import PhotosUI
import UIKit

class PublishViewController: UIViewController, UIGestureRecognizerDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {

    var saveInProgress: Bool = false
    
    @IBOutlet weak var titleField: UITextField!
    @IBOutlet weak var descriptionField: UITextView!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var namePrefixLabel: UILabel!
    @IBOutlet weak var depositField: UITextField!
    @IBOutlet weak var videoNameField: UITextField!
    @IBOutlet weak var selectVideoArea: UIView!
    
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var channelPickerView: UIPickerView!
    @IBOutlet weak var languagePickerView: UIPickerView!
    @IBOutlet weak var licensePickerView: UIPickerView!
    
    @IBOutlet weak var generateThumbnailButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var uploadingIndicator: UIView!
    
    var channels: [Claim] = []
    var currentClaim: Claim?
    var selectedVideoUrl: URL!
    var selectedItemProvider: NSItemProvider!
    var selectingVideo: Bool = false
    var selectingThumbnail: Bool = false
    
    var currentThumbnailImage: UIImage!
    var currentThumbnailUrl: String?
    var thumbnailGenerated: Bool = false
    var thumbnailUploadInProgress: Bool = false
    
    let namePrefixFormat = "odysee.com/%@"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "PublishForm", AnalyticsParameterScreenClass: "PublishViewController"])
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: false)
        
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        descriptionField.layer.borderColor = UIColor.systemGray5.cgColor
        descriptionField.layer.borderWidth = 1
        descriptionField.layer.cornerRadius = 4
        
        uploadingIndicator.layer.cornerRadius = 16
        
        loadChannels()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func addAnonymousPlaceholder() {
        let anonymousClaim: Claim = Claim()
        anonymousClaim.name = "Anonymous"
        anonymousClaim.claimId = "anonymous"
        channels.append(anonymousClaim)
    }
    
    func loadChannels() {
        DispatchQueue.main.async {
            self.startLoading()
        }
        
        var options = Dictionary<String, Any>()
        options["claim_type"] = ["channel"]
        options["page"] = 1
        options["page_size"] = 999
        options["resolve"] = true
        Lbry.apiCall(method: Lbry.methodClaimList, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                self.restoreButtons()
                self.showError(error: error)
                return
            }
            
            let result = data["result"] as? [String: Any]
            let items = result?["items"] as? [[String: Any]]
            if (items != nil) {
                var loadedClaims: [Claim] = []
                items?.forEach{ item in
                    let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                    do {
                        let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                        if (claim != nil) {
                            loadedClaims.append(claim!)
                        }
                    } catch let error {
                        print(error)
                    }
                }
                self.channels.removeAll()
                self.addAnonymousPlaceholder()
                self.channels.append(contentsOf: loadedClaims)
                Lbry.ownChannels = self.channels.filter { $0.claimId != "anonymous" }
            }
            
            DispatchQueue.main.async {
                self.restoreButtons()
                self.channelPickerView.reloadAllComponents()
                if self.channels.count > 1 {
                    self.channelPickerView.selectRow(1, inComponent: 0, animated: true)
                    self.namePrefixLabel.text = String(format: self.namePrefixFormat, self.channels[1].name! + "/")
                }
                self.populateFieldsForEdit()
            }
        })
    }
    
    func populateFieldsForEdit() {
        if currentClaim == nil {
            return
        }
        
        generateThumbnailButton.isHidden = true
        nameField.isEnabled = false
        nameField.text = currentClaim?.name
        titleField.text = currentClaim?.value!.title ?? ""
        descriptionField.text = currentClaim?.value!.description ?? ""
        depositField.text = currentClaim?.amount!
        selectVideoArea.isHidden = true
        
        if currentClaim?.value!.thumbnail != nil && !(currentClaim?.value!.thumbnail!.url ?? "").isBlank {
            let thumbnailUrl = currentClaim!.value!.thumbnail!.url!
            self.currentThumbnailUrl = thumbnailUrl
            thumbnailImageView.backgroundColor = UIColor.clear
            thumbnailImageView.load(url: URL(string: thumbnailUrl)!)
        }
        
        if currentClaim?.signingChannel != nil {
            let channelClaimId = currentClaim!.signingChannel!.claimId!
            if let index = channels.firstIndex(where: { $0.claimId == channelClaimId }) {
                self.channelPickerView.selectRow(Int(index), inComponent: 0, animated: true)
            }
        }
        
        if currentClaim?.value != nil {
            if let languages = currentClaim?.value?.languages {
                if languages.count > 0 {
                    if let index = Predefined.publishLanguages.firstIndex(where: { $0.code == languages[0] }) {
                        self.languagePickerView.selectRow(Int(index), inComponent: 0, animated: true)
                    }
                }
            }
            if let license = currentClaim?.value?.license {
                if let index = Predefined.licenses.firstIndex(where: { $0.name == license }) {
                    self.licensePickerView.selectRow(Int(index), inComponent: 0, animated: true)
                }
            }
        }
        
        uploadButton.setTitle("Update", for: .normal)
    }
        
    func startLoading() {
        DispatchQueue.main.async {
            self.loadingIndicator.isHidden = false
            self.cancelButton.isHidden = true
            self.uploadButton.isHidden = true
        }
    }
    
    func restoreButtons() {
        DispatchQueue.main.async {
            self.loadingIndicator.isHidden = true
            self.cancelButton.isHidden = false
            self.uploadButton.isHidden = false
        }
    }
    
    
    @IBAction func backTapped(_ sender: Any) {
        if saveInProgress {
            return
        }
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func selectVideoTapped(_ sender: UIButton) {
        showVideoPicker()
    }
    
    @IBAction func selectImageTapped(_ sender: UIButton) {
        showImagePicker()
    }
    
    @IBAction func generateThumbnailTapped(_ sender: UIButton) {
        generateThumbnailForVideo()
    }
    
    func generateThumbnailForVideo() {
        if thumbnailGenerated {
            // don't generate a thumbnail for the same video more than once
            // reset when a video is selected
            return
        }
        
        if selectedItemProvider == nil {
            showError(message: "Please select a video first")
            return
        }
        if thumbnailUploadInProgress {
            showError(message: "Please wait for the current thumbnail upload to finish")
            return
        }
        
        selectedItemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier, completionHandler: { url, error in
            guard let url = url, error == nil else {
                self.showError(message: "A thumbnail could not be generated for the selected video")
                return
            }
            
            do {
                let asset = AVAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                let timestamp = asset.duration
                let cgImage = try generator.copyCGImage(at: timestamp, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                self.currentThumbnailImage = thumbnail
                DispatchQueue.main.async {
                    self.thumbnailImageView.image = thumbnail
                }
                
                self.uploadThumbnail(image: thumbnail, generated: true)
            } catch {
                self.showError(message: "A thumbnail could not be generated for the selected video")
                return
            }
        })
    }
    
    func uploadThumbnail(image: UIImage, generated: Bool = false) {
        thumbnailUploadInProgress = true
        DispatchQueue.main.async {
            self.uploadingIndicator.isHidden = false
        }
        Helper.uploadImage(image: image, completion: { imageUrl, error in
            guard let imageUrl = imageUrl, error == nil else {
                DispatchQueue.main.async {
                    self.uploadingIndicator.isHidden = true
                }
                
                self.thumbnailUploadInProgress = false
                self.showError(error: error)
                return
            }
            
            if generated {
                self.thumbnailGenerated = true
            }
            DispatchQueue.main.async {
                self.uploadingIndicator.isHidden = true
            }
            self.thumbnailUploadInProgress = false
            self.currentThumbnailUrl = imageUrl
        })
    }
    
    @IBAction func cancelTapped(_ sender: UIButton) {
        if saveInProgress {
            return
        }
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func uploadTapped(_ sender: UIButton) {
        let name = nameField.text
        let deposit = Decimal(string: depositField.text!)
        let title = titleField.text
        let editMode = currentClaim != nil
        
        if thumbnailUploadInProgress {
            showError(message: "Please wait for the thumbnail to finish uploading")
            return
        }
        
        if name == nil || !LbryUri.isNameValid(name) {
            showError(message: String.localized("Please enter a valid name for the content URL"))
            return
        }
        if (title ?? "").isBlank {
            showError(message: String.localized("Please provide a title for your content"))
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
        
        if !editMode && selectedVideoUrl == nil {
            showError(message: "Please select a video to upload")
            return
        }
        
        var params: Dictionary<String, Any> = [
            "blocking": true,
            "bid": Helper.sdkAmountFormatter.string(from: deposit! as NSDecimalNumber)!,
            "title": (title ?? ""),
            "description": (descriptionField.text ?? ""),
            "thumbnail_url": (currentThumbnailUrl ?? "")
        ]
        
        if !editMode {
            params["name"] = name!
        }
        
        let selectedChannelIndex: Int = channelPickerView.selectedRow(inComponent: 0)
        if selectedChannelIndex > 0 {
            // not anonymous
            params["channel_id"] = channels[selectedChannelIndex].claimId
        }
        
        var releaseTimeSet = false
        if currentClaim != nil  {
            if !(currentClaim!.value?.releaseTime ?? "").isBlank {
                params["release_time"] = Int64(currentClaim!.value!.releaseTime!) ?? Int64(Date().timeIntervalSince1970)
                releaseTimeSet = true
            } else if currentClaim!.timestamp! > 0 {
                params["release_time"] = currentClaim!.timestamp!
                releaseTimeSet = true
            }
        }
        
        if !releaseTimeSet {
            params["release_time"] = Int(Date().timeIntervalSince1970)
        }
        
        let language = Predefined.publishLanguages[languagePickerView.selectedRow(inComponent: 0)]
        params["languages"] = [language.code!]
        
        let license = Predefined.licenses[licensePickerView.selectedRow(inComponent: 0)]
        params["license"] = license.name
        if !(license.url ?? "").isBlank {
            params["license_url"] = license.url!
        }
        // TODO: License url input field?
        
        saveInProgress = true
        startLoading()
        if editMode {
            params["claim_id"] = currentClaim?.claimId

            Lbry.apiCall(method: Lbry.methodStreamUpdate, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
                guard let _ = data, error == nil else {
                    self.saveInProgress = false
                    self.restoreButtons()
                    self.showError(error: error)
                    return
                }
                
                self.showMessage(message: String.localized("Your content was successfully updated. Changes will show up in a few minutes."))
                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: true)
                }
            })
        } else {
            uploadVideo(filename: selectedVideoUrl.lastPathComponent, params: params, completion: { data, error in
                guard let _ = data, error == nil else {
                    self.saveInProgress = false
                    self.restoreButtons()
                    self.showError(error: error)
                    return
                }
                
                self.saveInProgress = false
                self.restoreButtons()
                
                // show a message upon successful upload and then dismiss
                self.showMessage(message: String.localized("Your video was successfully uploaded. It will be available in a few minutes."))
                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: true)
                    let appDelegate = UIApplication.shared.delegate as! AppDelegate
                    appDelegate.mainTabViewController?.selectedIndex = 3
                }
            })
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == channelPickerView {
            let channel = channels[row]
            if channel.name!.lowercased() == "anonymous" {
                namePrefixLabel.text = String(format: namePrefixFormat, "")
            } else {
                namePrefixLabel.text = String(format: namePrefixFormat, channel.name! + "/")
            }
        }
    }
    
    func uploadVideo(filename: String, params: Dictionary<String, Any>, completion: @escaping ([String: Any]?, Error?) -> Void) {
        if selectedItemProvider != nil {
            selectedItemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier, completionHandler: { url, error in
                guard let videoUrl = url, error == nil else {
                    completion(nil, GenericError("The selected video could not be uploaded."))
                    return
                }
                
                let jsonPayload: Dictionary<String, Any> = [
                    "jsonrpc": "2.0",
                    "method": "publish",
                    "params": params,
                    "counter": Date().timeIntervalSince1970
                ];
                
                
                do {
                    let jsonData = try! JSONSerialization.data(withJSONObject: jsonPayload, options: .prettyPrinted)
                    let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)
                    print(jsonString!)
                    
                    var mimeType = "application/octet-stream"
                    let pathExt = videoUrl.pathExtension
                    if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExt as NSString, nil)?.takeRetainedValue() {
                        if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                            mimeType = mimetype as String
                        }
                    }
                    
                    let boundary = "Boundary-\(UUID().uuidString)"
                    var fieldData = "--\(boundary)\r\n"
                    fieldData.append("Content-Disposition: form-data; name=\"json_payload\"\r\n\r\n\(jsonString!)\r\n")
                    
                    let videoData = try Data(contentsOf: videoUrl)
                    let data = NSMutableData()
                    data.append("--\(boundary)\r\n".data(using: .utf8, allowLossyConversion: false)!)
                    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8, allowLossyConversion: false)!)
                    data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8, allowLossyConversion: false)!)
                    data.append(videoData)
                    data.append("\r\n".data(using: .utf8, allowLossyConversion: false)!)
                    
                    let reqBody = NSMutableData()
                    reqBody.append(fieldData.data(using: .utf8, allowLossyConversion: false)!)
                    reqBody.append(data as Data)
                    reqBody.append("--\(boundary)--\r\n".data(using: .utf8, allowLossyConversion: false)!)
                    
                    var req = URLRequest(url: URL(string: Lbry.lbrytvConnectionString)!)
                    req.httpMethod = "POST"
                    req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                    req.setValue(String(reqBody.count), forHTTPHeaderField: "Content-Length")
                    if (!(Lbryio.authToken ?? "").isBlank) {
                        req.addValue(Lbryio.authToken!, forHTTPHeaderField: "X-Lbry-Auth-Token")
                    }
                    req.httpBody = reqBody as Data
                    
                    let task = URLSession.shared.dataTask(with: req) { data, response, error in
                        guard let data = data, error == nil else {
                            completion(nil, error)
                            return
                        }
                        
                        do {
                            // TODO: remove
                            if let JSONString = String(data: data, encoding: String.Encoding.utf8) {
                               print(JSONString)
                            }
                            
                            let response = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                            if (response?["result"] != nil) {
                                completion(response, nil)
                            } else {
                                if response?["error"] == nil && response?["result"] == nil {
                                    completion(nil, nil)
                                } else if (response?["error"] as? String != nil) {
                                    completion(nil, LbryApiResponseError(response?["error"] as! String))
                                } else if let errorJson = response?["error"] as? [String: Any] {
                                    completion(nil, LbryApiResponseError(errorJson["message"] as! String))
                                } else {
                                    completion(nil, LbryApiResponseError("unknown api error"))
                                }
                            }
                        } catch let error {
                            completion(nil, error)
                        }
                    }
                    
                    task.resume()
                } catch let error {
                    print(error)
                    completion(nil, GenericError("An error occurred trying to upload the video. Please try again."))
                }
            })
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == channelPickerView {
            return channels.count
        } else if pickerView == languagePickerView {
            return Predefined.publishLanguages.count
        } else if pickerView == licensePickerView {
            return Predefined.licenses.count
        }
        
        return 0
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == channelPickerView {
            return channels[row].name
        } else if pickerView == languagePickerView {
            return Predefined.publishLanguages[row].localizedName
        } else if pickerView == licensePickerView {
            return Predefined.licenses[row].localizedName
        }
        
        return nil
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
    
    func showVideoPicker() {
        var config = PHPickerConfiguration()
        config.filter = .videos
        
        let pc = PHPickerViewController(configuration: config)
        pc.delegate = self
        pc.modalPresentationStyle = .overCurrentContext
        present(pc, animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[.editedImage] as? UIImage else {
            return
        }
        // reset thumbnail generated state here because the user selected a different image as a thumbnail
        thumbnailGenerated = false
        DispatchQueue.main.async {
            self.thumbnailImageView.image = image
        }
        uploadThumbnail(image: image)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        guard let provider = results.first?.itemProvider else { return }
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            self.selectedItemProvider = provider
            self.thumbnailGenerated = false
            provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: [:]) { [self] (videoURL, error) in
                if let url = videoURL as? URL {
                    self.selectedVideoUrl = url
                    DispatchQueue.main.async {
                        self.videoNameField.text = url.lastPathComponent
                    }
                }
            }
        }
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
