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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setClaim(claim: Claim) {
        titleLabel.text = claim.value?.title
        publisherLabel.text = claim.signingChannel != nil ? claim.signingChannel?.name : ""
        
        let releaseTime: Double = Double(claim.value?.releaseTime ?? "0")!
        let date: Date = NSDate(timeIntervalSince1970: releaseTime) as Date // TODO: Timezone check / conversion?
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        publishTimeLabel.text = formatter.localizedString(for: date, relativeTo: Date())
        
        // load thumbnail url
        if (claim.value?.thumbnail != nil && claim.value?.thumbnail?.url != nil) {
            thumbnailImageView.load(url: URL(string: (claim.value?.thumbnail?.url)!)!)
        }
    }

}
