//
//  GoLiveViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/04/2021.
//

import AVFoundation
import HaishinKit
import UIKit

class GoLiveViewController: UIViewController {

    var rtmpConnection: RTMPConnection!
    var rtmpStream: RTMPStream!
    var isStreaming = false
    var channels: [Claim] = []
    var streamKey: String? = nil
    var rtmpUrl: String = "rtmp://stream.odysee.com/live"
    var streamName: String? = nil
    var currentCamera: AVCaptureDevice.Position = .back
    var startingStream: Bool = false
    static let minStreamStake: Decimal = Decimal(50)
    
    @IBOutlet weak var precheckView: UIView!
    @IBOutlet weak var precheckLoadingView: UIView!
    @IBOutlet weak var precheckLabel: UILabel!
    @IBOutlet weak var cameraCaptureView: UIView!
    @IBOutlet weak var toggleStreamingButton: UIButton!
    @IBOutlet weak var spacemanImage: UIImageView!
    
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
        
        self.loadChannels()
        self.activateAudioSession()
        self.initStream()
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
        
        let options: Dictionary<String, Any> = ["claim_type": "channel", "page": 1, "page_size": 999, "resolve": true]
        Lbry.apiCall(method: Lbry.methodClaimList, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.precheckLoadingView.isHidden = true
                    self.spacemanImage.image = UIImage.init(named: "spaceman_sad")
                    self.precheckLabel.text = String.localized("An error occurred loading your channels. Please try again later.")
                }
                return
            }
            
            let result = data["result"] as? [String: Any]
            if let items = result?["items"] as? [[String: Any]] {
                var loadedClaims: [Claim] = []
                items.forEach{ item in
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
                self.channels.append(contentsOf: loadedClaims)
            }
            
            if self.channels.count > 0 {
                var effectiveAmount = Decimal(0)
                let channel = self.channels[0]
                if let meta = channel.meta {
                    effectiveAmount = Decimal(string: meta.effectiveAmount!)!
                }
                if effectiveAmount < GoLiveViewController.minStreamStake {
                    DispatchQueue.main.async {
                        self.precheckLoadingView.isHidden = true
                        self.spacemanImage.image = UIImage.init(named: "spaceman_sad")
                        self.precheckLabel.text = String(format: String.localized("You need have at least %@ credits staked (directly or through supports) on %@ to be able to livestream."),
                                                         String(describing: GoLiveViewController.minStreamStake), channel.name!)
                    }
                    return
                }
                
                self.loadLivestreamingClaim()
                return
            }
            
            DispatchQueue.main.async {
                self.precheckLoadingView.isHidden = true
                self.spacemanImage.image = UIImage.init(named: "spaceman_sad")
                self.precheckLabel.text = String.localized("You need to create a channel before you can livestream.")
            }
        })
    }
    
    
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
                    self.createLivestreamClaim()
                }
            }
        })
    }
    
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
                print(result)
                let signature = result["signature"] as? String
                let signing_ts = result["signing_ts"] as? String
                self.streamKey = self.createStreamKey(channel: channel, signature: signature!, signing_ts: signing_ts!)
                print(self.streamKey)
                
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
    
    func createLivestreamClaim() {
        // check eligibility? (50 credits staked on channel)
        let channel = channels[0] // use the first channel
        let title = String(format: "%@ livestream", channel.name!)
        let deposit: Decimal = Decimal(0.001)
        let options: Dictionary<String, Any> = [
            "blocking": true,
            "bid": Helper.sdkAmountFormatter.string(from: deposit as NSDecimalNumber)!,
            "title": title,
            "description": "",
            "thumbnail_url": "",
            "name": "livestream",
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
            
            self.loadLivestreamingClaim()
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
