//
//  GoLiveViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/04/2021.
//

import AVFoundation
import HaishinKit
import UIKit

class GoLiveViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var rtmpConnection: RTMPConnection!
    var rtmpStream: RTMPStream!
    var isStreaming = false
    var channels: [Claim] = []
    var streamKey: String? = nil
    var rtmpUrl: String = "rtmp://stream.odysee.com/live"
    var streamName: String? = nil
    var currentCamera: AVCaptureDevice.Position = .back
    var startingStream: Bool = false
    var selectedChannel: Claim? = nil
    var thumbnailUploadInProgress: Bool = false
    var currentThumbnailUrl: String?
    static let minStreamStake: Decimal = Decimal(50)
    
    @IBOutlet weak var precheckView: UIView!
    @IBOutlet weak var precheckLoadingView: UIView!
    @IBOutlet weak var precheckLabel: UILabel!
    @IBOutlet weak var cameraCaptureView: UIView!
    @IBOutlet weak var toggleStreamingButton: UIButton!
    @IBOutlet weak var spacemanImage: UIImageView!
    
    
    @IBOutlet weak var livestreamOptionsScrollView: UIScrollView!
    @IBOutlet weak var livestreamOptionsView: UIView!
    @IBOutlet weak var titleField: UITextField!
    
    @IBOutlet weak var channelPicker: UIPickerView!
    @IBOutlet weak var channelErrorLabel: UILabel!
    
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var uploadingIndicator: UIView!
    
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
        
        self.registerForKeyboardNotifications()
        self.loadChannels()
        self.activateAudioSession()
        self.initStream()
    }
    
    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let info = notification.userInfo
        let kbSize = (info![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.size
        let contentInsets = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: kbSize.height, right: 0.0)
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
            .sessionPreset: AVCaptureSession.Preset.hd1280x720
        ]
        rtmpStream.videoSettings = [
            .width: 1280,
            .height: 720,
            .bitrate: 4096
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
            let alert = UIAlertController(title: String.localized("Stop streaming?"), message: String.localized("Do you want to stop streaming?"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in self.closeStream() }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { action in }))
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
                showError(message: String.localized("The stream key was not successfully generated. Please try again later."))
                return
            }

            startingStream = true
            rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            rtmpConnection.connect(self.rtmpUrl)
            rtmpStream!.publish(self.streamKey!)
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
            showError(message: String.localized("Could not establish a connection to the streaming URL. Please try again."))
            // attempt connection retry?
        case RTMPConnection.Code.connectClosed.rawValue:
            isStreaming = false
        default:
            break
        }
    }

    @objc private func rtmpErrorHandler(_ notification: Notification) {
        // simply attempt to reconnect
        showError(message: String.localized("An error occurred trying to connect to the streaming URL. Please try again."))
        rtmpConnection.connect(self.rtmpUrl)
        rtmpStream.publish(self.streamKey!)
    }

    
    func loadChannels() {
        precheckLoadingView.isHidden = false
        
        Lbry.apiCall(method: Lbry.Methods.claimList,
                     params: .init(
                        claimType: [.channel],
                        page: 1,
                        pageSize: 999,
                        resolve: true),
                     authToken: Lbryio.authToken,
                     completion: didLoadChannels)
    }
    
    func canStreamOnChannel(_ channel: Claim?) -> Bool {
        if channel == nil {
            return false
        }
        
        var effectiveAmount = Decimal(0)
        let channel = self.channels[0]
        if channel.confirmations! < 1 {
            channelErrorLabel.text = String.localized("Your channel is still pending. Please wait a couple of minutes and try again.")
            return false
        }
        
        if let meta = channel.meta {
            effectiveAmount = Decimal(string: meta.effectiveAmount!)!
        }
        if effectiveAmount < GoLiveViewController.minStreamStake {
            channelErrorLabel.text = String(format: String.localized("You need to have at least %@ credits staked (directly or through supports) on %@ to be able to livestream."), String(describing: GoLiveViewController.minStreamStake), channel.name!)
            return false
        }
        
        return true
    }
    
    func didLoadChannels(_ result: Result<Page<Claim>, Error>) {
        assert(Thread.isMainThread)
        if case let .success(page) = result {
            channels.removeAll()
            channels.append(contentsOf: page.items)
            channelPicker.reloadAllComponents()
            
            if self.channels.count > 0 {
                // allow the user to choose a channel on the options before proceeding
                showLivestreamingOptions()
                return
            }
        
            precheckLoadingView.isHidden = true
            spacemanImage.image = UIImage.init(named: "spaceman_sad")
            precheckLabel.text = String.localized("You need to create a channel before you can livestream.")
            
            return
        }
        
        result.showErrorIfPresent()
        precheckLoadingView.isHidden = true
        self.spacemanImage.image = UIImage.init(named: "spaceman_sad")
        self.precheckLabel.text = String.localized("An error occurred loading your channels. Please try again later.")
    }
    
    func displayRequirementNotMet(message: String) {
        DispatchQueue.main.async {
            self.precheckLoadingView.isHidden = true
            self.spacemanImage.image = UIImage.init(named: "spaceman_sad")
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
                _ = self.canStreamOnChannel(self.selectedChannel)
            }
        }
    }
    
    @IBAction func continueTapped(_ sender: UIButton) {
        titleField.resignFirstResponder()
        
        if thumbnailUploadInProgress {
            showError(message: String.localized("Please wait for the thumbnail to finish uploading"))
            return
        }
        
        if (!canStreamOnChannel(selectedChannel)) {
            showError(message: String.localized("Please select a valid channel to continue"))
            return
        }
        
        // check that there is a title
        let title = titleField.text
        if (title ?? "").isBlank {
            showError(message: String.localized("Please specify a title for your stream"))
            return
        }

        self.precheckView.isHidden = false
        self.precheckLoadingView.isHidden = false
        self.livestreamOptionsView.isHidden = true
        self.createLivestreamClaim(title: title!)
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
    
    func signAndSetupStream(channel: Claim?) {
        let options: Dictionary<String, Any> = ["channel_id": channel!.claimId!, "hexdata": Helper.strToHex(channel!.name!)]
        Lbry.apiCall(method: Lbry.methodChannelSign, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.precheckLoadingView.isHidden = true
                    self.spacemanImage.image = UIImage.init(named: "spaceman_sad")
                    self.precheckLabel.text = String.localized("An error occurred trying to set up your livestream. Please try again later.")
                }
                return
            }
            
            if let result = data["result"] as? [String: Any] {
                let signature = result["signature"] as? String
                let signing_ts = result["signing_ts"] as? String
                self.streamKey = self.createStreamKey(channel: channel, signature: signature!, signing_ts: signing_ts!)
                
                DispatchQueue.main.async {
                    self.precheckLoadingView.isHidden = true
                    self.precheckView.isHidden = true
                }
                
                return
            }
            
            DispatchQueue.main.async {
                self.precheckLoadingView.isHidden = true
                self.spacemanImage.image = UIImage.init(named: "spaceman_sad")
                self.precheckLabel.text = String.localized("Your stream key could not be generated. Please try again later.")
            }
        })
    }
    
    func createStreamKey(channel: Claim?, signature: String, signing_ts: String) -> String {
        return String(format: "%@?d=%@&s=%@&t=%@", channel!.claimId!, Helper.strToHex(channel!.name!), signature, signing_ts)
    }
    
    func createLivestreamClaim(title: String) {
        // check eligibility? (50 credits fked on channel)
        let channel = channels[0] // use the first channel
        let deposit: Decimal = Decimal(0.001)
        let suffix: String = String(describing: Int(Date().timeIntervalSince1970))
        let options: Dictionary<String, Any> = [
            "blocking": true,
            "bid": Helper.sdkAmountFormatter.string(from: deposit as NSDecimalNumber)!,
            "title": title,
            "description": "",
            "thumbnail_url": currentThumbnailUrl ?? (channel.value?.thumbnail?.url ?? ""),
            "name": String(format: "livestream-%@", suffix),
            "channel_id": channel.claimId!,
            "release_time": Int(Date().timeIntervalSince1970)
        ]
        
        Lbry.apiCall(method: Lbry.methodPublish, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let _ = data, error == nil else {
                DispatchQueue.main.async {
                    self.precheckLoadingView.isHidden = true
                    self.spacemanImage.image = UIImage.init(named: "spaceman_sad")
                    self.precheckLabel.text = String.localized("An error occurred trying to set up your livestream. Please try again later.")
                }
                return
            }
            
            // The claim was successfully set up. Create the stream key and start
            self.signAndSetupStream(channel: self.channels[0])
        })
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.channels.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.channels.map{ $0.name }[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedChannel = self.channels[row]
        _ = canStreamOnChannel(selectedChannel)
    }
    
    @IBAction func selectImageTapped(_ sender: UIButton) {
        self.view.endEditing(true)
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
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
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
