//
//  ChannelCollectionViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/12/2020.
//

import UIKit

class ChannelCollectionViewCell: UICollectionViewCell {
    @IBOutlet var thumbnailImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!

    var currentClaim: Claim?

    func setClaim(claim: Claim) {
        if let currentClaim, claim.claimId != currentClaim.claimId {
            // reset the thumbnail image (to prevent the user from seeing image load changes when scrolling due to cell reuse)
            thumbnailImageView.image = UIImage(named: "spaceman")
        }
        currentClaim = claim

        thumbnailImageView.rounded()
        if let thumbnailUrl = claim.value?.thumbnail?.url,
           let url = URL(string: thumbnailUrl)
        {
            thumbnailImageView.load(url: url)
        } else {
            thumbnailImageView.image = UIImage(named: "spaceman")
            thumbnailImageView.backgroundColor = Helper.lightPrimaryColor
        }

        backgroundColor = claim.selected ? Helper.lightPrimaryColor : UIColor.clear
        titleLabel.textColor = claim.selected ? UIColor.white : UIColor.label

        titleLabel.text = claim.value?.title
    }
}
