//
//  ChannelCollectionViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/12/2020.
//

import UIKit

class ChannelCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    var currentClaim: Claim?
    
    func setClaim(claim: Claim) {
        if (currentClaim != nil && claim.claimId != currentClaim!.claimId) {
            // reset the thumbnail image (to prevent the user from seeing image load changes when scrolling due to cell reuse)
            thumbnailImageView.image = UIImage.init(named: "spaceman")
        }
        currentClaim = claim
        
        thumbnailImageView.rounded()
        if (claim.value?.thumbnail != nil && claim.value?.thumbnail?.url != nil) {
            thumbnailImageView.load(url: URL(string: (claim.value?.thumbnail?.url)!)!)
        } else {
            thumbnailImageView.image = UIImage.init(named: "spaceman")
            thumbnailImageView.backgroundColor = Helper.lightPrimaryColor
        }
        
        
        
        titleLabel.text = claim.value?.title
    }
}
