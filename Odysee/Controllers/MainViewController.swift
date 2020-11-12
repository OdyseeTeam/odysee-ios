//
//  MainViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 11/11/2020.
//

import AVFoundation
import UIKit

class MainViewController: UIViewController {

    @IBOutlet weak var headerArea: UIView!
    @IBOutlet weak var headerAreaHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var miniPlayerBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var miniPlayerView: UIView!
    @IBOutlet weak var miniPlayerMediaView: UIView!
    @IBOutlet weak var miniPlayerTitleLabel: UILabel!
    @IBOutlet weak var miniPlayerPublisherLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainViewController = self
        // Do any additional setup after loading the view.

    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "main_nav" {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainNavigationController = segue.destination as? UINavigationController
        }
    }
    
    // Experimental
    func toggleHeaderVisibility(hidden: Bool) {
        headerArea.isHidden = hidden
        headerAreaHeightConstraint.constant = hidden ? 0 : 52
        view!.layoutIfNeeded()
    }
    
    func adjustMiniPlayerBottom(bottom: CGFloat) {
        miniPlayerBottomConstraint.constant = bottom
    }
    
    @IBAction func closeMiniPlayer(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if (appDelegate.player != nil) {
            appDelegate.player?.pause()
            appDelegate.player = nil
        }
        toggleMiniPlayer(hidden: true)
        miniPlayerTitleLabel.text = ""
        miniPlayerPublisherLabel.text = ""
        appDelegate.currentClaim = nil
    }
    
    @IBAction func openSearch(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "search_vc") as! SearchViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func openCurrentClaim(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if (appDelegate.currentClaim != nil) {
            let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
            vc.claim = appDelegate.currentClaim
            
            let transition = CATransition()
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            transition.type = .push
            transition.subtype = .fromTop
            appDelegate.mainNavigationController?.view.layer.add(transition, forKey: kCATransition)
            appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
        }
    }
    
    func updateMiniPlayer() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if (appDelegate.currentClaim != nil && appDelegate.player != nil) {
            miniPlayerTitleLabel.text = appDelegate.currentClaim?.value?.title
            miniPlayerPublisherLabel.text = appDelegate.currentClaim?.signingChannel?.value?.title
            
            
            let mediaViewLayer: CALayer = miniPlayerMediaView.layer
            let playerLayer: AVPlayerLayer = AVPlayerLayer(player: appDelegate.player)
            playerLayer.frame = mediaViewLayer.bounds
            playerLayer.videoGravity = .resizeAspectFill
            mediaViewLayer.sublayers?.popLast()
            mediaViewLayer.addSublayer(playerLayer)
        }
    }
    
    func toggleMiniPlayer(hidden: Bool) {
        miniPlayerView.isHidden = hidden
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
