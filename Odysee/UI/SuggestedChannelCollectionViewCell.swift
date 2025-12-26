//
//  SuggestedChannelCollectionViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 30/11/2020.
//

import UIKit

class SuggestedChannelCollectionViewCell: UICollectionViewCell {
    @IBOutlet var thumbnailImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var tagView: UIView!
    @IBOutlet var tagLabel: UILabel!

    var currentClaim: Claim?

    func setClaim(claim: Claim) {
        if let currentClaim, claim.claimId != currentClaim.claimId {
            // reset the thumbnail image (to prevent the user from seeing image load changes when scrolling due to cell reuse)
            thumbnailImageView.image = nil
        }
        currentClaim = claim

        thumbnailImageView.rounded()
        if let thumbnailUrlValue = claim.value?.thumbnail?.url,
           let thumbnailUrl = URL(string: thumbnailUrlValue)
        {
            thumbnailImageView.load(url: thumbnailUrl)
        } else {
            thumbnailImageView.image = UIImage(named: "spaceman")
            thumbnailImageView.backgroundColor = Helper.lightPrimaryColor
        }

        titleLabel.text = claim.value?.title

        tagLabel.isHidden = true
        tagLabel.text = ""
        if let tags = claim.value?.tags, tags.count > 0 {
            tagLabel.text = tags[0]
        }
    }

    func setSelected(selected: Bool) {
        if selected {
            backgroundColor = Helper.lightPrimaryColor
            tagLabel.textColor = UIColor.white
            titleLabel.textColor = UIColor.white
        } else {
            backgroundColor = nil
            tagLabel.textColor = .label
            titleLabel.textColor = .label
        }
    }
}
