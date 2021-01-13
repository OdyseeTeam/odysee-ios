//
//  CommentTableViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/12/2020.
//

import UIKit

class CommentTableViewCell: UITableViewCell {

    var currentComment: Comment?
    var authorImageMap: Dictionary<String, String> = [:]
    
    @IBOutlet weak var authorThumbnailView: UIImageView!
    @IBOutlet weak var authorNameLabel: UILabel!
    @IBOutlet weak var commentBodyLabel: UILabel!
    @IBOutlet weak var leadingLayoutConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setAuthorImageMap(map: Dictionary<String, String>) {
        authorImageMap = map
        displayAuthorImage()
    }
    
    func displayAuthorImage() {
        if currentComment?.channelUrl != nil {
            if let thumbnailUrlStr = authorImageMap[currentComment!.channelUrl!] {
                authorThumbnailView.backgroundColor = UIColor.clear
                authorThumbnailView.load(url: URL(string: thumbnailUrlStr)!)
            } else {
                authorThumbnailView.image = UIImage.init(named: "spaceman")
                authorThumbnailView.backgroundColor = Helper.lightPrimaryColor
            }
        }
    }

    func setComment(comment: Comment) {
        if (currentComment != nil && comment.commentId != currentComment!.commentId) {
            authorThumbnailView.image = UIImage.init(named: "spaceman")
            authorThumbnailView.backgroundColor = Helper.lightPrimaryColor
        }
        
        authorThumbnailView.rounded()
        currentComment = comment
        
        displayAuthorImage()
        leadingLayoutConstraint.constant = !(comment.parentId ?? "").isBlank ? 66 : 16
        authorNameLabel.text = comment.channelName
        commentBodyLabel.text = comment.comment
    }
}
