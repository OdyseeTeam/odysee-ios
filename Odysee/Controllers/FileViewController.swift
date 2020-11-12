//
//  FileViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 06/11/2020.
//

import AVKit
import AVFoundation
import UIKit

class FileViewController: UIViewController, UIGestureRecognizerDelegate {

    var claim: Claim?
    
    @IBOutlet weak var titleArea: UIView!
    @IBOutlet weak var publisherArea: UIView!
    @IBOutlet weak var descriptionArea: UIView!
    
    @IBOutlet weak var mediaView: UIView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var viewCountLabel: UILabel!
    @IBOutlet weak var timeAgoLabel: UILabel!
    
    @IBOutlet weak var publisherImageView: UIImageView!
    @IBOutlet weak var publisherTitleLabel: UILabel!
    @IBOutlet weak var publisherNameLabel: UILabel!
    
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        appDelegate.mainController.toggleMiniPlayer(hidden: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.updateMiniPlayer()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if (appDelegate.player != nil) {
            appDelegate.mainController.toggleMiniPlayer(hidden: false)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        // Do any additional setup after loading the view.
        displayClaim()
        loadAndDisplayViewCount()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    func displayClaim() {
        titleLabel.text = claim?.value?.title
        
        let releaseTime: Double = Double(claim?.value?.releaseTime ?? "0")!
        let date: Date = NSDate(timeIntervalSince1970: releaseTime) as Date // TODO: Timezone check / conversion?
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        timeAgoLabel.text = formatter.localizedString(for: date, relativeTo: Date())
        
        // publisher
        publisherImageView.rounded()
        publisherTitleLabel.text = claim?.signingChannel?.value?.title
        publisherNameLabel.text = claim?.signingChannel?.name
        publisherImageView.load(url: URL(string: (claim?.signingChannel?.value?.thumbnail?.url!)!)!)
        
        // details
        descriptionLabel.text = claim?.value?.description
        
        // display video content
        let avpc: AVPlayerViewController = AVPlayerViewController()
        self.addChild(avpc)
        avpc.view.frame = self.mediaView.bounds
        self.mediaView.addSubview(avpc.view)
        avpc.didMove(toParent: self)
        
        do {
            // enable audio in silent mode
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            // pass
        }
        
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if (appDelegate.player != nil && appDelegate.currentClaim != nil && appDelegate.currentClaim?.claimId == claim?.claimId) {
            avpc.player = appDelegate.player
            return
        }
        
        appDelegate.currentClaim = claim
        if (appDelegate.player != nil) {
            appDelegate.player?.pause()
        }
        let videoUrl = URL(string: getStreamingUrl(claim: claim!))
        appDelegate.player = AVPlayer(url: videoUrl!)
        avpc.player = appDelegate.player
        avpc.player?.play()
    }
    
    func getStreamingUrl(claim: Claim) -> String {
        let claimName: String = claim.name!
        let claimId: String = claim.claimId!
        return String(format: "https://cdn.lbryplayer.xyz/content/claims/%@/%@/stream", claimName, claimId);
    }
    
    func loadAndDisplayViewCount() {
        var options = Dictionary<String, String>()
        options["claim_id"] = claim?.claimId
        try! Lbryio.call(resource: "file", action: "view_count", options: options, method: Lbryio.methodGet, completion: { data, error in
            if (error != nil) {
                // could load the view count for display
                DispatchQueue.main.async {
                    self.viewCountLabel.isHidden = true
                }
                return
            }
            DispatchQueue.main.async {
                let viewCount:Int = (data as! NSArray)[0] as! Int
                self.viewCountLabel.isHidden = false
                self.viewCountLabel.text = String(format: viewCount == 1 ? String.localized("%d view") : String.localized("%d views"), viewCount)
            }
        })
    }
}
