//
//  ChannelListTableViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/12/2020.
//

import UIKit

class ChannelListTableViewCell: UITableViewCell {

    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var publishTimeLabel: UILabel!
    @IBOutlet weak var detailsStackView: UIView!
    @IBOutlet weak var placeholderLabel: UILabel!
    
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
            thumbnailImageView.image = UIImage.init(named: "spaceman")
            thumbnailImageView.backgroundColor = Helper.lightPrimaryColor
        }
        
        currentClaim = claim
        detailsStackView.isHidden = currentClaim?.claimId == "new"
        placeholderLabel.isHidden = !(currentClaim?.claimId == "new")
        
        thumbnailImageView.rounded()
        if claim.value?.thumbnail != nil && !(claim.value?.thumbnail!.url ?? "").isBlank {
            let thumbnailUrl = URL(string: (claim.value?.thumbnail?.url)!)!
            thumbnailImageView.backgroundColor = UIColor.clear
            thumbnailImageView.load(url: thumbnailUrl)
        } else {
            thumbnailImageView.image = UIImage.init(named: "spaceman")
            thumbnailImageView.backgroundColor = Helper.lightPrimaryColor
        }
        
        titleLabel.text = claim.value?.title ?? claim.name
        nameLabel.text = claim.name
        
        var releaseTime: Double = Double(claim.value?.releaseTime ?? ("0"))!
        if (releaseTime == 0) {
            releaseTime = Double(claim.timestamp ?? 0)
        }
        if releaseTime > 0 {
            let date: Date = NSDate(timeIntervalSince1970: releaseTime) as Date // TODO: Timezone check / conversion?
            publishTimeLabel.text = Helper.fullRelativeDateFormatter.localizedString(for: date, relativeTo: Date())
        } else {
            publishTimeLabel.text = "Pending"
        }
    }
}
