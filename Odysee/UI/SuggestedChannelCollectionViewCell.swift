//
//  ChannelCollectionViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 30/11/2020.
//

import UIKit

class SuggestedChannelCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tagView: UIView!
    @IBOutlet weak var tagLabel: UILabel!
    
    var currentClaim: Claim?
    
    func setClaim(claim: Claim) {
        if (currentClaim != nil && claim.claimId != currentClaim!.claimId) {
            // reset the thumbnail image (to prevent the user from seeing image load changes when scrolling due to cell reuse)
            thumbnailImageView.image = nil
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
        tagLabel.text = ""
        if (claim.value?.tags != nil && claim.value?.tags!.count ?? 0 > 0) {
            tagLabel.text = claim.value?.tags![0]
        }
    }
}
