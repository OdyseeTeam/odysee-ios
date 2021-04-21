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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
            // print(error)
        }
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: .back)) { error in
            // print(error)
        }

        let hkView = HKView(frame: view.bounds)
        hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
        hkView.attachStream(rtmpStream)

        view.addSubview(hkView)

    }
    
    @IBAction func goLiveTapped(_ sender: UIButton) {
        //rtmpConnection.connect("rtmp://localhost/appName/instanceName")
        //rtmpStream.publish("streamName")
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
