//
//  PublishViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 26/02/2021.
//

import FirebaseAnalytics
import FirebaseCrashlytics
import OrderedCollections
import os
import Photos
import PhotosUI
import UIKit

class PublishViewController: UIViewController, UIGestureRecognizerDelegate, UIPickerViewDelegate,
    UIPickerViewDataSource,
    UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate
{
    var saveInProgress: Bool = false

    @IBOutlet var titleField: UITextField!
    @IBOutlet var descriptionField: UITextView!
    @IBOutlet var nameField: UITextField!
    @IBOutlet var namePrefixLabel: UILabel!
    @IBOutlet var videoNameField: UITextField!
    @IBOutlet var selectVideoArea: UIView!
    @IBOutlet var guidelinesTextView: UITextView!

    @IBOutlet var thumbnailImageView: UIImageView!
    @IBOutlet var channelPickerView: UIPickerView!
    @IBOutlet var languagePickerView: UIPickerView!
    @IBOutlet var licensePickerView: UIPickerView!

    @IBOutlet var generateThumbnailButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var uploadButton: UIButton!
    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var uploadingIndicator: UIView!

    var channels: [Claim] = []
    var uploads: OrderedSet<Claim> = []
    var currentClaim: Claim?
    let videoPickerController = VideoPickerController()
    var selectingThumbnail: Bool = false

    var currentThumbnailImage: UIImage!
    var currentThumbnailUrl: String?
    var thumbnailGenerated: Bool = false
    var thumbnailUploadInProgress: Bool = false

    let namePrefixFormat = "odysee.com/%@"

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "PublishForm",
                AnalyticsParameterScreenClass: "PublishViewController",
            ]
        )

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        descriptionField.layer.borderColor = UIColor.systemGray5.cgColor
        descriptionField.layer.borderWidth = 1
        descriptionField.layer.cornerRadius = 4

        uploadingIndicator.layer.cornerRadius = 16

        let guidelinesString = String.localized(
            "By continuing, you accept the Odysee Terms of Service and community guidelines."
        )
        let attributed = try? NSMutableAttributedString(
            data: guidelinesString.data,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        )
        guidelinesTextView.attributedText = attributed
        guidelinesTextView.textColor = .label
        guidelinesTextView.font = .systemFont(ofSize: 12)

        var languageKey = Locale.current.languageCode ?? ContentSources.languageCodeEN
        if let scriptCode = Locale.current.scriptCode {
            languageKey.append("-\(scriptCode)")
        }
        let regionCode = Locale.current.regionCode ?? ContentSources.regionCodeUS
        if languageKey != ContentSources.languageCodeEN, regionCode == ContentSources.regionCodeBR {
            languageKey.append("-\(regionCode)")
        }
        if let index = Predefined.supportedLanguages.firstIndex(where: { $0.code == languageKey }) {
            languagePickerView.selectRow(Int(index), inComponent: 0, animated: true)
        }

        loadChannels()
        loadUploads()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func addAnonymousPlaceholder() {
        let anonymousClaim = Claim(
            claimId: "anonymous",
            name: "Anonymous"
        )
        channels.append(anonymousClaim)
    }

    func loadUploads() {
        Lbry.apiCall(
            method: BackendMethods.claimList,
            params: .init(
                claimType: [.stream],
                page: 1,
                pageSize: 999,
                resolve: true
            )
        )
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

        Lbry.apiCall(
            method: BackendMethods.claimList,
            params: .init(
                claimType: [.channel],
                page: 1,
                pageSize: 999,
                resolve: true
            )
        )
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

        Task {
            let defaultChannelId = await Wallet.shared.defaultChannelId
            let index = channels.firstIndex { $0.claimId == defaultChannelId } ?? 0
            if channels.count > index {
                channelPickerView.selectRow(index, inComponent: 0, animated: true)
                namePrefixLabel.text = String(format: namePrefixFormat, (channels[index].name ?? "") + "/")
            }
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
        titleField.text = currentClaim?.value?.title ?? ""
        descriptionField.text = currentClaim?.value?.description ?? ""
        selectVideoArea.isHidden = true

        if let thumbnailUrlValue = currentClaim?.value?.thumbnail?.url,
           !thumbnailUrlValue.isBlank,
           let thumbnailUrl = URL(string: thumbnailUrlValue)
        {
            currentThumbnailUrl = thumbnailUrlValue
            thumbnailImageView.backgroundColor = UIColor.clear
            thumbnailImageView.load(url: thumbnailUrl)
        }

        if let channelClaimId = currentClaim?.signingChannel?.claimId {
            if let index = channels.firstIndex(where: { $0.claimId == channelClaimId }) {
                channelPickerView.selectRow(Int(index), inComponent: 0, animated: true)
            }
        }

        if currentClaim?.value != nil {
            if let languages = currentClaim?.value?.languages {
                if languages.count > 0 {
                    if let index = Predefined.supportedLanguages.firstIndex(where: { $0.code == languages[0] }) {
                        languagePickerView.selectRow(Int(index), inComponent: 0, animated: true)
                    }
                }
            }
            if let license = currentClaim?.value?.license {
                if let index = Predefined.licenses.firstIndex(where: { $0.name == license }) {
                    licensePickerView.selectRow(Int(index), inComponent: 0, animated: true)
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
        view.endEditing(true)
        if saveInProgress {
            return
        }
        navigationController?.popViewController(animated: true)
    }

    @IBAction func selectVideoTapped(_ sender: UIButton) {
        view.endEditing(true)
        videoPickerController.pickVideo(from: self, completion: didPickVideo)
    }

    @IBAction func selectImageTapped(_ sender: UIButton) {
        view.endEditing(true)
        showImagePicker()
    }

    @IBAction func generateThumbnailTapped(_ sender: UIButton) {
        view.endEditing(true)
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
        view.endEditing(true)
        if saveInProgress {
            return
        }
        navigationController?.popViewController(animated: true)
    }

    @IBAction func uploadTapped(_ sender: UIButton) {
        view.endEditing(true)

        let name = nameField.text
        let deposit = Helper.minimumDeposit
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
        guard let name else {
            showError(message: "name is nil and fell through")
            return
        }
        if uploads.contains(where: { $0.name?.lowercased() == name.lowercased() }) {
            showError(message: String(
                format: String
                    .localized("You have already uploaded a claim with the name: %@. Please use a different name."),
                name
            ))
            return
        }
        if title.isBlank {
            showError(message: String.localized("Please provide a title for your content"))
            return
        }

        // prev deposit only set when it's edit mode
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

        if !editMode, videoPickerController.pickedVideoName == nil {
            showError(message: "Please select a video to upload")
            return
        }

        var params: [String: Any] = [
            "blocking": true,
            "bid": Helper.minimumDepositString,
            "title": title ?? "",
            "description": descriptionField.text ?? "",
            "thumbnail_url": currentThumbnailUrl ?? "",
        ]

        if !editMode {
            params["name"] = name
        }

        let selectedChannelIndex: Int = channelPickerView.selectedRow(inComponent: 0)
        if selectedChannelIndex > 0, channels.count > selectedChannelIndex {
            // not anonymous
            params["channel_id"] = channels[selectedChannelIndex].claimId
        }

        var releaseTimeSet = false
        if let currentClaim {
            if let releaseTime = currentClaim.value?.releaseTime, !releaseTime.isBlank {
                params["release_time"] = Int64(releaseTime) ?? Int64(Date().timeIntervalSince1970)
                releaseTimeSet = true
            } else if let timestamp = currentClaim.timestamp, timestamp > 0 {
                params["release_time"] = timestamp
                releaseTimeSet = true
            }
        }

        if !releaseTimeSet {
            params["release_time"] = Int(Date().timeIntervalSince1970)
        }

        params["languages"] = [Predefined.supportedLanguages[languagePickerView.selectedRow(inComponent: 0)].code]

        let license = Predefined.licenses[licensePickerView.selectedRow(inComponent: 0)]
        params["license"] = license.name
        if let licenseUrl = license.url, !licenseUrl.isBlank {
            params["license_url"] = licenseUrl
        }
        // TODO: License url input field?

        saveInProgress = true
        startLoading()
        if editMode {
            params["claim_id"] = currentClaim?.claimId

            Lbry.apiCall(
                method: Lbry.methodStreamUpdate,
                params: params,
                url: Lbry.lbrytvURL,
                completion: { data, error in
                    guard data != nil, error == nil else {
                        self.saveInProgress = false
                        self.restoreButtons()
                        self.showError(error: error)
                        return
                    }

                    self
                        .showMessage(
                            message: String
                                .localized(
                                    "Your content was successfully updated. Changes will show up in a few minutes."
                                )
                        )
                    DispatchQueue.main.async {
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            )
        } else {
            progressView.observedProgress = uploadVideo(params: params, completion: { data, error in
                guard data != nil, error == nil else {
                    self.saveInProgress = false
                    self.restoreButtons()
                    self.showError(error: error)
                    return
                }

                self.saveInProgress = false
                self.restoreButtons()

                // show a message upon successful upload and then dismiss
                self
                    .showMessage(
                        message: String
                            .localized("Your video was successfully uploaded. It will be available in a few minutes.")
                    )
                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: true)
                    AppDelegate.shared.mainTabViewController?.selectedIndex = 3
                }
            })
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == channelPickerView {
            guard channels.count > row else {
                return
            }

            let channel = channels[row]
            let name = channel.name ?? ""
            if name.lowercased() == "anonymous" {
                namePrefixLabel.text = String(format: namePrefixFormat, "")
            } else {
                namePrefixLabel.text = String(format: namePrefixFormat, name + "/")
            }
        }
    }

    func uploadVideo(params: [String: Any], completion: @escaping ([String: Any]?, Error?) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        videoPickerController.getVideoURL { urlResult in
            Task {
                guard case let .success(videoUrl) = urlResult else {
                    completion(nil, GenericError("The selected video could not be uploaded."))
                    return
                }

                let jsonPayload: [String: Any] = [
                    "jsonrpc": "2.0",
                    "method": "publish",
                    "params": params,
                    "counter": Date().timeIntervalSince1970,
                ]

                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: jsonPayload, options: .prettyPrinted)
                    guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
                        completion(nil, GenericError("Couldn't encode payload"))
                        return
                    }
                    Log.verboseJSON.logIfEnabled(.debug, jsonString)

                    var mimeType = "application/octet-stream"
                    let pathExt = videoUrl.pathExtension

                    let types = UTType.types(tag: pathExt, tagClass: .filenameExtension, conformingTo: nil)
                    if let mimetype = types.first?.preferredMIMEType {
                        mimeType = mimetype
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
                    let headerData = header.data
                    let headerStream = InputStream(data: headerData)
                    headerStream.open()

                    var fileError: NSError?
                    var fileStream: InputStream?
                    NSFileCoordinator().coordinate(
                        readingItemAt: videoUrl, options: .forUploading, error: &fileError
                    ) { fileURL in
                        // Per the docs, with the .forUploading option, you can use the file outside of this
                        // accessor block, but you need to open a file-descriptor to it inside. So that's what we do.
                        fileStream = InputStream(fileAtPath: fileURL.path)
                        fileStream?.open()
                    }
                    if let fe = fileError {
                        assertionFailure()
                        throw fe
                    }
                    guard let fileStream else {
                        completion(nil, GenericError("Couldn't open file for uploading"))
                        return
                    }

                    let footer = "\r\n--\(boundary)--\r\n"
                    let footerData = footer.data
                    let footerStream = InputStream(data: footerData)
                    footerStream.open()
                    guard let videoSize = try FileManager.default.attributesOfItem(
                        atPath: videoUrl.path
                    )[.size] as? Int else {
                        completion(nil, GenericError("Couldn't get videoSize"))
                        return
                    }
                    let contentLength = headerData.count + videoSize + footerData.count

                    var req = URLRequest(url: Lbry.uploadURL)
                    req.httpMethod = "POST"
                    req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                    req.setValue(String(contentLength), forHTTPHeaderField: "Content-Length")
                    req.addValue(await AuthToken.token, forHTTPHeaderField: "X-Lbry-Auth-Token")
                    req.httpBodyStream = Multistream(streams: [headerStream, fileStream, footerStream])

                    let task = URLSession.shared.dataTask(with: req) { data, _, error in
                        guard let data = data, error == nil else {
                            completion(nil, error)
                            return
                        }

                        do {
                            if let string = String(data: data, encoding: .utf8) {
                                Log.verboseJSON.logIfEnabled(.debug, string)
                            }

                            let response = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                            if response?["result"] != nil {
                                completion(response, nil)
                            } else {
                                if response?["error"] == nil, response?["result"] == nil {
                                    completion(nil, nil)
                                } else if let error = response?["error"] as? String {
                                    completion(nil, LbryApiResponseError(error))
                                } else if let errorJson = response?["error"] as? [String: Any],
                                          let errorMessage = errorJson["message"] as? String
                                {
                                    completion(nil, LbryApiResponseError(errorMessage))
                                } else {
                                    completion(nil, LbryApiResponseError("unknown api error"))
                                }
                            }
                        } catch {
                            completion(nil, error)
                        }
                    }

                    progress.addChild(task.progress, withPendingUnitCount: 1)
                    task.resume()
                } catch {
                    Crashlytics.crashlytics().recordImmediate(error: error)
                    completion(nil, GenericError("An error occurred trying to upload the video. Please try again."))
                }
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
            return Predefined.supportedLanguages.count
        } else if pickerView == licensePickerView {
            return Predefined.licenses.count
        }

        return 0
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == channelPickerView {
            guard channels.count > row else {
                return nil
            }

            return channels[row].name
        } else if pickerView == languagePickerView {
            return Predefined.supportedLanguages[row].name
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

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
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
