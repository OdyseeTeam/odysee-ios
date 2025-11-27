//
//  ChatMessageTableViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 09/04/2021.
//

import UIKit

class ChatMessageTableViewCell: UITableViewCell {
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var messageLabel: UILabel!

    var currentComment: Comment?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func setComment(comment: Comment) {
        if let currentComment, comment.commentId != currentComment.commentId {
            nameLabel.text = nil
            messageLabel.text = nil
        }

        nameLabel.text = comment.channelName
        nameLabel.sizeToFit()
        messageLabel.text = comment.comment
    }
}
