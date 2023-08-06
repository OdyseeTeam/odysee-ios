//
//  ChannelCollectionViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/12/2020.
//

import UIKit
import Odysee

class ChannelCollectionViewCell: UICollectionViewCell {
    @IBOutlet var thumbnailImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!

    var currentClaim: Claim?

    func setClaim(claim: Claim) {
        if currentClaim != nil, claim.claimId != currentClaim!.claimId {
            // reset the thumbnail image (to prevent the user from seeing image load changes when scrolling due to cell reuse)
            thumbnailImageView.image = UIImage(named: "spaceman")
        }
        currentClaim = claim

        thumbnailImageView.rounded()
        if claim.value?.thumbnail != nil, claim.value?.thumbnail?.url != nil {
            thumbnailImageView.load(url: URL(string: (claim.value?.thumbnail?.url)!)!)
        } else {
            thumbnailImageView.image = UIImage(named: "spaceman")
            thumbnailImageView.backgroundColor = Helper.lightPrimaryColor
        }

        backgroundColor = currentClaim!.selected ? Helper.lightPrimaryColor : UIColor.clear
        titleLabel.textColor = currentClaim!.selected ? UIColor.white : UIColor.label

        titleLabel.text = claim.value?.title
    }
}
