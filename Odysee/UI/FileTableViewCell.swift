//
//  FileTableViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 08/11/2020.
//

import UIKit

class FileTableViewCell: UITableViewCell {

    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var publisherLabel: UILabel!
    @IBOutlet weak var publishTimeLabel: UILabel!
    @IBOutlet weak var durationView: UIView!
    @IBOutlet weak var durationLabel: UILabel!
    
    var currentClaim: Claim?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setClaim(claim: Claim) {
        if (currentClaim != nil && claim.claimId != currentClaim!.claimId) {
            // reset the thumbnail image (to prevent the user from seeing image load changes when scrolling due to cell reuse)
            thumbnailImageView.image = nil
        }
        currentClaim = claim
        
        titleLabel.text = claim.value?.title
        publisherLabel.text = claim.signingChannel != nil ? claim.signingChannel?.name : ""
        // load thumbnail url
        if (claim.value?.thumbnail != nil && claim.value?.thumbnail?.url != nil) {
            thumbnailImageView.load(url: URL(string: (claim.value?.thumbnail?.url)!)!)
        }
        
        var releaseTime: Double = Double(claim.value?.releaseTime ?? ("0"))!
        if (releaseTime == 0) {
            releaseTime = Double(claim.timestamp ?? 0)
        }
        let date: Date = NSDate(timeIntervalSince1970: releaseTime) as Date // TODO: Timezone check / conversion?
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        publishTimeLabel.text = formatter.localizedString(for: date, relativeTo: Date())
        
        var duration: Int64 = 0
        if (claim.value?.video != nil || claim.value?.audio != nil) {
            let streamInfo: Claim.StreamInfo? = claim.value?.video != nil ? claim.value?.video : claim.value?.audio
            duration = streamInfo?.duration ?? 0
        }
        
        durationView.isHidden = duration <= 0
        if (duration > 0) {
            if (duration < 60) {
                durationLabel.text = String(format: "0:%02d", duration)
            } else {
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.unitsStyle = .positional
                durationLabel.text = formatter.string(from: TimeInterval(duration))
            }
        }
    }
}
