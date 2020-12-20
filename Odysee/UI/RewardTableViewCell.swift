//
//  RewardTableViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 19/12/2020.
//

import UIKit

class RewardTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var uptoLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    
    var currentReward: Reward?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func setReward(reward: Reward) {
        titleLabel.text = reward.rewardTitle
        descriptionLabel.text = reward.rewardDescription
        amountLabel.text = reward.displayAmount
        uptoLabel.isHidden = (reward.rewardRange ?? "").isBlank || reward.rewardRange!.firstIndex(of: "-") == nil
    }
}
