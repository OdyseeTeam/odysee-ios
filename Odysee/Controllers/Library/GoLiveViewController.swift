//
//  GoLiveViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/04/2021.
//

import AVFoundation
import HaishinKit
import UIKit

class GoLiveViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate,
    UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    var rtmpConnection: RTMPConnection!
    var rtmpStream: RTMPStream!
    var isStreaming = false
    var channels: [Claim] = []
    var streamKey: String?
    var rtmpUrl: String = "rtmp://stream.odysee.com/live"
    var streamName: String?
    var currentCamera: AVCaptureDevice.Position = .back
    var startingStream: Bool = false
    var selectedChannel: Claim?
    var thumbnailUploadInProgress: Bool = false
    var currentThumbnailUrl: String?
    var waitForConfirmationTimer: Timer?
    static let minStreamStake = Decimal(50)

    @IBOutlet var precheckView: UIView!
    @IBOutlet var precheckLoadingView: UIView!
    @IBOutlet var precheckLabel: UILabel!
    @IBOutlet var cameraCaptureView: UIView!
    @IBOutlet var toggleStreamingButton: UIButton!
    @IBOutlet var spacemanImage: UIImageView!

    @IBOutlet var livestreamOptionsScrollView: UIScrollView!
    @IBOutlet var livestreamOptionsView: UIView!
    @IBOutlet var titleField: UITextField!

    @IBOutlet var channelPicker: UIPickerView!
    @IBOutlet var channelErrorLabel: UILabel!

    @IBOutlet var thumbnailImageView: UIImageView!
    @IBOutlet var uploadingIndicator: UIView!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        appDelegate.mainController.toggleMiniPlayer(hidden: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        precheckLoadingView.layer.cornerRadius = 16

        registerForKeyboardNotifications()
        loadChannels()
        activateAudioSession()

        if UITraitCollection.current.userInterfaceIdiom == .pad {
            showMultitaskingWarning()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        initStream()
    }

    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        let info = notification.userInfo
        let kbSize = (info![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.size
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: kbSize.height, right: 0.0)
        livestreamOptionsScrollView.contentInset = contentInsets
        livestreamOptionsScrollView.scrollIndicatorInsets = contentInsets
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        livestreamOptionsScrollView.contentInset = contentInsets
        livestreamOptionsScrollView.scrollIndicatorInsets = contentInsets
    }

    func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print(error)
        }
    }

    func initStream() {
        rtmpConnection = RTMPConnection()
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.captureSettings = [
            .fps: 30,
            .sessionPreset: AVCaptureSession.Preset.hd1280x720,
        ]
        rtmpStream.videoSettings = [
            .width: 1280,
            .height: 720,
            .bitrate: 4096,
        ]
        rtmpStream.attachAudio(AVCaptureDevice.default(for: AVMediaType.audio)) { error in
            print(error)
        }
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: .back)) { error in
            print(error)
        }

        let hkView = HKView(frame: cameraCaptureView.bounds)
        hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
        hkView.attachStream(rtmpStream)

        cameraCaptureView.addSubview(hkView)
    }

    @IBAction func closeTapped(_ sender: UIButton) {
        if isStreaming {
            // show alert to stop broadcast first
            let alert = UIAlertController(
                title: String.localized("Stop streaming?"),
                message: String.localized("Do you want to stop streaming?"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in self.closeStream() }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { _ in }))
            present(alert, animated: true, completion: nil)
            return
        }

        closeStream()
    }

    func closeStream() {
        if rtmpConnection != nil {
            rtmpConnection.close()
        }
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainNavigationController?.popViewController(animated: true)
        }
    }

    @IBAction func toggleCameraTapped(_ sender: UIButton) {
        if currentCamera == .back {
            rtmpStream.attachCamera(DeviceUtil.device(withPosition: .front))
            currentCamera = .front
        } else {
            rtmpStream.attachCamera(DeviceUtil.device(withPosition: .back))
            currentCamera = .back
        }
    }

    @IBAction func toggleStreamingTapped(_ sender: UIButton) {
        if startingStream {
            return
        }

        if !isStreaming {
            if (streamKey ?? "").isBlank {
                // show an error
                showError(
                    message: String
                        .localized("The stream key was not successfully generated. Please try again later.")
                )
                return
            }

            startingStream = true
            rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            rtmpConnection.connect(rtmpUrl)
            rtmpStream!.publish(streamKey!)
            return
        }

        // stopping stream
        rtmpConnection.close()
        isStreaming = false
        startingStream = false
        DispatchQueue.main.async {
            self.toggleStreamingButton.setTitle(String.localized("Start streaming"), for: .normal)
        }
    }

    @objc private func rtmpStatusHandler(_ notification: Notification) {
        startingStream = false

        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String else {
            return
        }

        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            isStreaming = true
            DispatchQueue.main.async {
                self.toggleStreamingButton.setTitle(String.localized("Stop streaming"), for: .normal)
            }
        case RTMPConnection.Code.connectFailed.rawValue:
            isStreaming = false
            showError(
                message: String
                    .localized("Could not establish a connection to the streaming URL. Please try again.")
            )
        // attempt connection retry?
        case RTMPConnection.Code.connectClosed.rawValue:
            isStreaming = false
        default:
            break
        }
    }

    @objc private func rtmpErrorHandler(_ notification: Notification) {
        // simply attempt to reconnect
        showError(
            message: String
                .localized("An error occurred trying to connect to the streaming URL. Please try again.")
        )
        rtmpConnection.connect(rtmpUrl)
        rtmpStream.publish(streamKey!)
    }

    func loadChannels() {
        precheckLoadingView.isHidden = false

        Lbry.apiCall(
            method: Lbry.Methods.claimList,
            params: .init(
                claimType: [.channel],
                page: 1,
                pageSize: 999,
                resolve: true
            )
        )
        .subscribeResult(didLoadChannels)
    }

    /// Checks if it's possible to stream on `channel`, and update the error label with the reason if not.
    func checkCanStreamOnChannel(_ channel: Claim?) -> Bool {
        guard let channel = channel else {
            return false
        }

        if channel.confirmations! < 1 {
            channelErrorLabel.isHidden = false
            channelErrorLabel.text = String
                .localized("Your channel is still pending. Please wait a couple of minutes and try again.")
            return false
        }

        // Disabled due to lack of server side checking for now
//        var effectiveAmount = Decimal(0)
//        if let meta = channel.meta {
//            effectiveAmount = Decimal(string: meta.effectiveAmount!)!
//        }
//        if effectiveAmount < GoLiveViewController.minStreamStake {
//            channelErrorLabel.isHidden = false
//            channelErrorLabel.text = String(
//                format: String
//                    .localized(
//                        "You need to have at least %@ credits staked (directly or through supports) on %@ to be able to livestream."
//                    ),
//                String(describing: GoLiveViewController.minStreamStake),
//                channel.name!
//            )
//            return false
//        }

        channelErrorLabel.isHidden = true
        return true
    }

    func didLoadChannels(_ result: Result<Page<Claim>, Error>) {
        assert(Thread.isMainThread)
        if case let .success(page) = result {
            channels.removeAll()
            channels.append(contentsOf: page.items)
            channelPicker.reloadAllComponents()

            let index = channels.firstIndex { $0.claimId == Lbry.defaultChannelId } ?? 0
            if channels.count >= index {
                channelPicker.selectRow(index, inComponent: 0, animated: true)
            }

            if self.channels.count > 0 {
                // allow the user to choose a channel on the options before proceeding
                showLivestreamingOptions()
                return
            }

            precheckLoadingView.isHidden = true
            spacemanImage.image = UIImage(named: "spaceman_sad")
            precheckLabel.text = String.localized("You need to create a channel before you can livestream.")

            return
        }

        result.showErrorIfPresent()
        precheckLoadingView.isHidden = true
        spacemanImage.image = UIImage(named: "spaceman_sad")
        precheckLabel.text = String.localized("An error occurred loading your channels. Please try again later.")
    }

    func showMultitaskingWarning() {
        let alert = UIAlertController(
            title: String.localized("Warning"),
            message: String.localized("Streaming will pause and may not resume correctly if you use Multitasking"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func displayRequirementNotMet(message: String) {
        DispatchQueue.main.async {
            self.precheckLoadingView.isHidden = true
            self.spacemanImage.image = UIImage(named: "spaceman_sad")
            self.precheckLabel.text = message
        }
    }

    func showLivestreamingOptions() {
        DispatchQueue.main.async {
            self.precheckLoadingView.isHidden = true
            self.precheckView.isHidden = true
            self.livestreamOptionsView.isHidden = false
            self.titleField.becomeFirstResponder()

            // check the selected picker item
            if self.channels.count > 0 {
                self.selectedChannel = self.channels[self.channelPicker.selectedRow(inComponent: 0)]
                _ = self.checkCanStreamOnChannel(self.selectedChannel)
            }
        }
    }

    @IBAction func continueTapped(_ sender: UIButton) {
        titleField.resignFirstResponder()

        if thumbnailUploadInProgress {
            showError(message: String.localized("Please wait for the thumbnail to finish uploading"))
            return
        }

        if !checkCanStreamOnChannel(selectedChannel) {
            showError(message: String.localized("Please select a valid channel to continue"))
            return
        }
        let channel = selectedChannel! // Confirmed non-nil by checkCanStreamOnChannel

        // check that there is a title
        let title = titleField.text
        if (title ?? "").isBlank {
            showError(message: String.localized("Please specify a title for your stream"))
            return
        }

        precheckView.isHidden = false
        precheckLoadingView.isHidden = false
        precheckLabel.text = String.localized("Please wait, your livestream claim is pending confirmation.")
        livestreamOptionsView.isHidden = true
        createLivestreamClaim(title: title!, channel: channel)
    }

    /* TODO: Determine if we want to be able to reuse existing claims
     func loadLivestreamingClaim() {
         let options: Dictionary<String, Any> = ["claim_type": "stream", "page": 1, "page_size": 1, "resolve": true, "has_no_source": true]
         Lbry.apiCall(method: Lbry.methodClaimList, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
             guard let data = data, error == nil else {
                 DispatchQueue.main.async {
                     self.precheckLoadingView.isHidden = true
                     self.spacemanImage.image = UIImage.init(named: "spaceman_sad")
                     self.precheckLabel.text = String.localized("An error occurred trying to set up your livestream. Please try again later.")
                 }
                 return
             }

             var numClaims = 0
             let result = data["result"] as? [String: Any]
             if let items = result?["items"] as? [[String: Any]] {
                 numClaims = items.count
                 if (numClaims > 0) {
                     // livestream
                     do {
                         let json = try JSONSerialization.data(withJSONObject: items[0], options: [.prettyPrinted, .sortedKeys])
                         let claim: Claim? = try JSONDecoder().decode(Claim.self, from: json)
                         // TODO: Do not use self.channels[0]. Maybe get channel from claim.
                         self.signAndSetupStream(channel: self.channels[0])
                     } catch {
                         DispatchQueue.main.async {
                             self.spacemanImage.image = UIImage.init(named: "spaceman_sad")
                             self.precheckLabel.text = String.localized("An error occurred trying to set up your livestream. Please try again later.")
                         }
                         return
                     }
                 } else {
                     //self.createLivestreamClaim()
                 }
             }
         })
     }*/

    func signAndSetupStream(channel: Claim) {
        Lbry.apiCall(
            method: Lbry.Methods.channelSign,
            params: .init(channelId: channel.claimId!, hexdata: Helper.strToHex(channel.name!))
        )
        .subscribeResult { result in
            switch result {
            case .failure:
                self.precheckLoadingView.isHidden = true
                self.spacemanImage.image = UIImage(named: "spaceman_sad")
                self.precheckLabel.text = String
                    .localized("Your stream key could not be generated. Please try again later.")
            case let .success(data):
                self.streamKey = self.createStreamKey(
                    channel: channel,
                    signature: data.signature,
                    signingTs: data.signingTs
                )
                self.precheckLoadingView.isHidden = true
                self.precheckView.isHidden = true
            }
        }
    }

    func createStreamKey(channel: Claim, signature: String, signingTs: String) -> String {
        return String(
            format: "%@?d=%@&s=%@&t=%@",
            channel.claimId!,
            Helper.strToHex(channel.name!),
            signature,
            signingTs
        )
    }

    func waitForConfirmation(txid: String, channel: Claim) {
        DispatchQueue.main.async {
            func didLoadTxo(_ result: Result<Page<Txo>, Error>) {
                if case let .success(page) = result,
                   let confirmations = page.items.first?.confirmations,
                   confirmations > 0
                {
                    self.signAndSetupStream(channel: channel)

                    self.waitForConfirmationTimer?.invalidate()
                }
            }

            self.waitForConfirmationTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                Lbry.apiCall(
                    method: Lbry.Methods.txoList,
                    params: .init(
                        type: [.stream],
                        txid: txid
                    )
                ).subscribeResult(didLoadTxo)
            }
        }
    }

    func createLivestreamClaim(title: String, channel: Claim) {
        // check eligibility? (50 credits fked on channel)
        let deposit = Decimal(0.001)
        let suffix = String(describing: Int(Date().timeIntervalSince1970))
        let options: [String: Any] = [
            "blocking": true,
            "bid": Helper.sdkAmountFormatter.string(from: deposit as NSDecimalNumber)!,
            "title": title,
            "description": "",
            "thumbnail_url": currentThumbnailUrl ?? (channel.value?.thumbnail?.url ?? ""),
            "name": String(format: "livestream-%@", suffix),
            "channel_id": channel.claimId!,
            "release_time": Int(Date().timeIntervalSince1970),
        ]

        Lbry.apiCall(
            method: Lbry.methodPublish,
            params: options,
            connectionString: Lbry.lbrytvConnectionString,
            authToken: Lbryio.authToken,
            completion: { data, error in
                guard let data = data, error == nil else {
                    DispatchQueue.main.async {
                        self.precheckLoadingView.isHidden = true
                        self.spacemanImage.image = UIImage(named: "spaceman_sad")
                        self.precheckLabel.text = String
                            .localized("An error occurred trying to set up your livestream. Please try again later.")
                    }
                    return
                }

                // The claim was successfully set up.
                // Wait for the claim to be confirmed, then create the stream key and start
                let result = data["result"] as? [String: Any]
                guard let txid = result?["txid"] as? String else {
                    self
                        .displayRequirementNotMet(
                            message: String
                                .localized("Could not get txid from publish API call.")
                        )
                    return
                }
                self.waitForConfirmation(txid: txid, channel: channel)
            }
        )
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return channels.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return channels.map(\.name)[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedChannel = channels[row]
        _ = checkCanStreamOnChannel(selectedChannel)
    }

    @IBAction func selectImageTapped(_ sender: UIButton) {
        view.endEditing(true)
        showImagePicker()
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
        didGetThumbnail(.success(image))
    }

    func didGetThumbnail(_ result: Result<UIImage, Error>) {
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
            DispatchQueue.main.async {
                self.uploadingIndicator.isHidden = true
            }
            self.thumbnailUploadInProgress = false
            self.currentThumbnailUrl = imageUrl
        })
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
