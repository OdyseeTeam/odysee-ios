//
//  CommentTableViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/12/2020.
//

import UIKit

class CommentTableViewCell: UITableViewCell {
    weak var viewController: CommentsViewController?
    var currentComment: Comment?
    var authorImageMap = [String: URL]()

    @IBOutlet var authorThumbnailView: UIImageView!
    @IBOutlet var authorNameLabel: UILabel!
    @IBOutlet var commentBodyLabel: UILabel!
    @IBOutlet var replyCountButton: UIButton!
    @IBOutlet var replyButton: UIButton!

    @IBOutlet var fireReactionContainer: UIView!
    @IBOutlet var slimeReactionContainer: UIView!
    @IBOutlet var fireReactionImage: UIImageView!
    @IBOutlet var fireReactionLabel: UILabel!
    @IBOutlet var slimeReactionImage: UIImageView!
    @IBOutlet var slimeReactionLabel: UILabel!

    @IBOutlet var leadingLayoutConstraint: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func setAuthorImageMap(map: [String: URL]) {
        authorImageMap = map
        displayAuthorImage()
    }

    func displayAuthorImage() {
        if currentComment?.channelUrl != nil {
            if let thumbnailUrl = authorImageMap[currentComment!.channelUrl!] {
                let optimisedUrl = thumbnailUrl.makeImageURL(spec: ClaimTableViewCell.channelImageSpec)
                authorThumbnailView.backgroundColor = UIColor.clear
                authorThumbnailView.load(url: optimisedUrl)
            } else {
                authorThumbnailView.image = UIImage(named: "spaceman")
                authorThumbnailView.backgroundColor = Helper.lightPrimaryColor
            }
        }
    }

    func setComment(comment: Comment) {
        if currentComment != nil && comment.commentId != currentComment!.commentId {
            authorThumbnailView.image = UIImage(named: "spaceman")
            authorThumbnailView.backgroundColor = Helper.lightPrimaryColor
        }

        authorThumbnailView.rounded()
        currentComment = comment

        displayAuthorImage()
        leadingLayoutConstraint.constant = !(comment.parentId ?? "").isBlank ? 66 : 16
        replyButton.isHidden = !(comment.parentId ?? "").isBlank
        replyCountButton.isHidden = (comment.replies ?? 0) == 0 || (comment.repliesLoaded ?? false)
        replyCountButton.setTitle(
            String(
                format: comment.replies == 1 ? String.localized("%d reply") : String.localized("%d replies"),
                comment.replies ?? 0
            ),
            for: .normal
        )

        authorNameLabel.text = comment.channelName
        commentBodyLabel.text = comment.comment
        fireReactionLabel.text = String(describing: comment.numLikes ?? 0)
        slimeReactionLabel.text = String(describing: comment.numDislikes ?? 0)
        fireReactionImage.tintColor = (comment.isLiked ?? false) ? Helper.fireActiveColor : UIColor.label
        slimeReactionImage.tintColor = (comment.isDisliked ?? false) ? Helper.slimeActiveColor : UIColor.label

        let authorTapGesture = UITapGestureRecognizer(target: self, action: #selector(authorTapped(_:)))
        authorNameLabel.addGestureRecognizer(authorTapGesture)

        let fireTapGesture = UITapGestureRecognizer(target: self, action: #selector(fireReactionTapped(_:)))
        fireReactionContainer.addGestureRecognizer(fireTapGesture)

        let slimeTapGesture = UITapGestureRecognizer(target: self, action: #selector(slimeReactionTapped(_:)))
        slimeReactionContainer.addGestureRecognizer(slimeTapGesture)
    }

    @objc func authorTapped(_ sender: Any) {
        let url = LbryUri.tryParse(url: currentComment!.channelUrl!, requireProto: false)
        if url != nil {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = appDelegate.mainViewController?.storyboard?
                .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
            vc.claimUrl = url
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func fireReactionTapped(_ sender: Any) {
        if viewController != nil, currentComment != nil {
            viewController!.react(currentComment!, type: Helper.reactionTypeLike)
        }
    }

    @objc func slimeReactionTapped(_ sender: Any) {
        if viewController != nil, currentComment != nil {
            viewController!.react(currentComment!, type: Helper.reactionTypeDislike)
        }
    }

    @IBAction func replyCountTapped(_ sender: UIButton) {
        if viewController != nil, currentComment != nil {
            viewController!.loadReplies(currentComment!)
        }
    }

    @IBAction func replyTapped(_ sender: UIButton) {
        if viewController != nil, currentComment != nil {
            viewController!.setReplyToComment(currentComment!)
        }
    }
}
