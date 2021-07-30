//
//  PublishViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 26/02/2021.
//

import MobileCoreServices
import Firebase
import os
import OrderedCollections
import Photos
import PhotosUI
import UIKit

class PublishViewController: UIViewController, UIGestureRecognizerDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {

    var saveInProgress: Bool = false
    
    @IBOutlet weak var scrollView: UIScrollView!
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
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var uploadingIndicator: UIView!
    
    var channels: [Claim] = []
    var uploads: OrderedSet<Claim> = []
    var currentClaim: Claim?
    let videoPickerController = makeVideoPickerController()
    var selectingThumbnail: Bool = false
    
    var currentThumbnailImage: UIImage!
    var currentThumbnailUrl: String?
    var thumbnailGenerated: Bool = false
    var thumbnailUploadInProgress: Bool = false
    
    let namePrefixFormat = "odysee.com/%@"
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "PublishForm", AnalyticsParameterScreenClass: "PublishViewController"])
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: false)
        
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.view.endEditing(true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        registerForKeyboardNotifications()
        descriptionField.layer.borderColor = UIColor.systemGray5.cgColor
        descriptionField.layer.borderWidth = 1
        descriptionField.layer.cornerRadius = 4
        
        uploadingIndicator.layer.cornerRadius = 16
        
        self.depositField.text = Helper.minimumDepositString
        loadChannels()
        loadUploads()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let info = notification.userInfo
        let kbSize = (info![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.size
        let contentInsets = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: kbSize.height, right: 0.0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }
    
    func addAnonymousPlaceholder() {
        let anonymousClaim: Claim = Claim()
        anonymousClaim.name = "Anonymous"
        anonymousClaim.claimId = "anonymous"
        channels.append(anonymousClaim)
    }
    
    func loadUploads() {
        Lbry.apiCall(method: Lbry.Methods.claimList,
                     params: .init(
                        claimType: [.stream],
                        page: 1,
                        pageSize: 999,
                        resolve: true))
            .subscribeResult(didLoadUploads)
    }
    
    func didLoadUploads(_ result: Result<Page<Claim>, Error>) {
        guard case let .success(page) = result else {
            return
        }
        
        uploads.append(contentsOf: page.items)
        Lbry.ownUploads = uploads.filter { $0.claimId != "new" }
    }

    func loadChannels() {
        DispatchQueue.main.async {
            self.startLoading()
        }
        
        Lbry.apiCall(method: Lbry.Methods.claimList,
                     params: .init(claimType: [.channel],
                                   page: 1,
                                   pageSize: 999,
                                   resolve: true))
            .subscribeResult(didLoadChannels)
    }
    
    func didLoadChannels(_ result: Result<Page<Claim>, Error>) {
        restoreButtons()
        guard case let .success(page) = result else {
            result.showErrorIfPresent()
            return
        }
        channels.removeAll(keepingCapacity: true)
        addAnonymousPlaceholder()
        channels.append(contentsOf: page.items)
        Lbry.ownChannels = channels.filter { $0.claimId != "anonymous" }
        channelPickerView.reloadAllComponents()
        if channels.count > 1 {
            channelPickerView.selectRow(1, inComponent: 0, animated: true)
            namePrefixLabel.text = String(format: namePrefixFormat, channels[1].name! + "/")
        }
        populateFieldsForEdit()
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
            self.progressView.isHidden = false
            self.cancelButton.isHidden = true
            self.uploadButton.isHidden = true
        }
    }
    
    func restoreButtons() {
        DispatchQueue.main.async {
            self.progressView.isHidden = true
            self.cancelButton.isHidden = false
            self.uploadButton.isHidden = false
        }
    }
    
    
    @IBAction func backTapped(_ sender: Any) {
        self.view.endEditing(true)
        if saveInProgress {
            return
        }
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func selectVideoTapped(_ sender: UIButton) {
        self.view.endEditing(true)
        videoPickerController.pickVideo(from: self, completion: didPickVideo)
    }
    
    @IBAction func selectImageTapped(_ sender: UIButton) {
        self.view.endEditing(true)
        showImagePicker()
    }
    
    @IBAction func generateThumbnailTapped(_ sender: UIButton) {
        self.view.endEditing(true)
        generateThumbnailForVideo()
    }
    
    func generateThumbnailForVideo() {
        if thumbnailGenerated {
            // don't generate a thumbnail for the same video more than once
            // reset when a video is selected
            return
        }
        
        if thumbnailUploadInProgress {
            showError(message: "Please wait for the current thumbnail upload to finish")
            return
        }
        
        videoPickerController.getVideoURL { urlResult in
            let thumbResult: Result<UIImage, Error> = urlResult.flatMap { url in
                Result {
                    let asset = AVAsset(url: url)
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    let timestamp = asset.duration
                    let cgImage = try generator.copyCGImage(at: timestamp, actualTime: nil)
                    return UIImage(cgImage: cgImage)
                }
            }
            DispatchQueue.main.async {
                self.didGetThumbnail(thumbResult, generated: true)
            }
        }
    }
    
    func didGetThumbnail(_ result: Result<UIImage, Error>, generated: Bool) {
        assert(Thread.isMainThread)
        guard case let .success(image) = result else {
            showError(error: GenericError("Could not get thumbnail image"))
            return
        }

        thumbnailUploadInProgress = true
        uploadingIndicator.isHidden = false
        thumbnailImageView.image = image
        
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
        self.view.endEditing(true)
        if saveInProgress {
            return
        }
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func uploadTapped(_ sender: UIButton) {
        self.view.endEditing(true)
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
        if self.uploads.contains(where: { $0.name!.lowercased() == name!.lowercased() }) {
            showError(message: String(format: String.localized("You have already uploaded a claim with the name: %@. Please use a different name."), name!))
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
        
        // prev deposit only set when it's edit mode
        let prevDeposit: Decimal? = currentClaim != nil ? Decimal(string: currentClaim!.amount!) : 0
        if Lbry.walletBalance == nil || deposit! - (prevDeposit ?? 0) > Lbry.walletBalance!.available! {
            showError(message: "Deposit cannot be higher than your wallet balance")
            return
        }
        
        if !editMode && videoPickerController.pickedVideoName == nil {
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
            progressView.observedProgress = uploadVideo(params: params, completion: { data, error in
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
    
    func uploadVideo(params: Dictionary<String, Any>, completion: @escaping ([String: Any]?, Error?) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        videoPickerController.getVideoURL { urlResult in
            guard case let .success(videoUrl) = urlResult else {
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
                let jsonData = try JSONSerialization.data(withJSONObject: jsonPayload, options: .prettyPrinted)
                let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)!
                Log.verboseJSON.logIfEnabled(.debug, jsonString)
                
                var mimeType = "application/octet-stream"
                let pathExt = videoUrl.pathExtension
                if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExt as NSString, nil)?.takeRetainedValue() {
                    if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                        mimeType = mimetype as String
                    }
                }
                
                let boundary = "Boundary-\(UUID().uuidString)"
                
                let header = """
                --\(boundary)\r
                Content-Disposition: form-data; name=\"json_payload\"\r
                \r
                \(jsonString)\r
                --\(boundary)\r
                Content-Disposition: form-data; name=\"file\"; filename=\"\(videoUrl.lastPathComponent)\"\r
                Content-Type: \(mimeType)\r
                \r
                
                """
                let headerData = header.data(using: .utf8)!
                let headerStream = InputStream(data: headerData)
                headerStream.open()
                
                var fileError: NSError?
                var fileStream: InputStream!
                NSFileCoordinator().coordinate(readingItemAt: videoUrl, options: .forUploading, error: &fileError) { fileURL in
                    // Per the docs, with the .forUploading option, you can use the file outside of this
                    // accessor block, but you need to open a file-descriptor to it inside. So that's what we do.
                    fileStream = InputStream(fileAtPath: fileURL.path)!
                    fileStream.open()
                }
                if let fe = fileError {
                    assertionFailure()
                    throw fe
                }

                let footer = "\r\n--\(boundary)--\r\n"
                let footerData = footer.data(using: .utf8)!
                let footerStream = InputStream(data: footerData)
                footerStream.open()
                let videoSize = try FileManager.default.attributesOfItem(atPath: videoUrl.path)[.size] as! Int
                let contentLength = headerData.count + videoSize + footerData.count
                
                var req = URLRequest(url: Lbry.uploadURL)
                req.httpMethod = "POST"
                req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                req.setValue(String(contentLength), forHTTPHeaderField: "Content-Length")
                if (!(Lbryio.authToken ?? "").isBlank) {
                    req.addValue(Lbryio.authToken!, forHTTPHeaderField: "X-Lbry-Auth-Token")
                }
                req.httpBodyStream = Multistream(streams: [headerStream, fileStream, footerStream])
                
                let task = URLSession.shared.dataTask(with: req) { data, response, error in
                    guard let data = data, error == nil else {
                        completion(nil, error)
                        return
                    }
                    
                    do {
                        Log.verboseJSON.logIfEnabled(.debug, String(data: data, encoding: .utf8)!)
                        
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
                
                progress.addChild(task.progress, withPendingUnitCount: 1)
                task.resume()
            } catch let error {
                print(error)
                completion(nil, GenericError("An error occurred trying to upload the video. Please try again."))
            }
        }
        return progress
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
    
    func didPickVideo(_ picked: Bool) {
        guard picked else {
            return
        }
        thumbnailGenerated = false
        videoNameField.text = videoPickerController.pickedVideoName
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[.editedImage] as? UIImage else {
            return
        }
        didGetThumbnail(.success(image), generated: false)
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
