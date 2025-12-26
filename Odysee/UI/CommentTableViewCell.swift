//
//  CommentTableViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/12/2020.
//

import SafariServices
import UIKit

class CommentTableViewCell: UITableViewCell {
    weak var viewController: CommentsViewController?
    var currentComment: Comment?
    var authorImageMap = [String: URL]()

    @IBOutlet var authorThumbnailView: UIImageView!
    @IBOutlet var authorNameLabel: UILabel!
    @IBOutlet var commentBodyLabel: UILabel!
    @IBOutlet var replyCountButton: UIButton!

    @IBOutlet var fireReactionContainer: UIView!
    @IBOutlet var slimeReactionContainer: UIView!
    @IBOutlet var fireReactionImage: UIImageView!
    @IBOutlet var fireReactionLabel: UILabel!
    @IBOutlet var slimeReactionImage: UIImageView!
    @IBOutlet var slimeReactionLabel: UILabel!

    @IBOutlet var blockChannelContainer: UIView!
    @IBOutlet var reportContentContainer: UIView!

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
        if let channelUrl = currentComment?.channelUrl {
            if let thumbnailUrl = authorImageMap[channelUrl],
               let optimisedUrl = thumbnailUrl.makeImageURL(spec: ClaimTableViewCell.channelImageSpec)
            {
                authorThumbnailView.backgroundColor = UIColor.clear
                authorThumbnailView.load(url: optimisedUrl)
            } else {
                authorThumbnailView.image = UIImage(named: "spaceman")
                authorThumbnailView.backgroundColor = Helper.lightPrimaryColor
            }
        }
    }

    func setComment(comment: Comment) {
        if let currentComment, comment.commentId != currentComment.commentId {
            authorThumbnailView.image = UIImage(named: "spaceman")
            authorThumbnailView.backgroundColor = Helper.lightPrimaryColor
        }

        authorThumbnailView.rounded()
        currentComment = comment

        displayAuthorImage()
        leadingLayoutConstraint.constant = CGFloat(comment.replyDepth * 16)
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
        if fireReactionLabel.text.isEmpty {
            fireReactionLabel.text = "0"
        }
        slimeReactionLabel.text = String(describing: comment.numDislikes ?? 0)
        if slimeReactionLabel.text.isEmpty {
            slimeReactionLabel.text = "0"
        }
        fireReactionImage.tintColor = (comment.isLiked ?? false) ? Helper.fireActiveColor : UIColor.label
        slimeReactionImage.tintColor = (comment.isDisliked ?? false) ? Helper.slimeActiveColor : UIColor.label

        let authorTapGesture = UITapGestureRecognizer(target: self, action: #selector(authorTapped(_:)))
        authorNameLabel.addGestureRecognizer(authorTapGesture)

        let fireTapGesture = UITapGestureRecognizer(target: self, action: #selector(fireReactionTapped(_:)))
        fireReactionContainer.addGestureRecognizer(fireTapGesture)

        let slimeTapGesture = UITapGestureRecognizer(target: self, action: #selector(slimeReactionTapped(_:)))
        slimeReactionContainer.addGestureRecognizer(slimeTapGesture)

        let blockTapGesture = UITapGestureRecognizer(target: self, action: #selector(blockChannelTapped(_:)))
        blockChannelContainer.addGestureRecognizer(blockTapGesture)

        let reportTapGesture = UITapGestureRecognizer(target: self, action: #selector(reportContentTapped(_:)))
        reportContentContainer.addGestureRecognizer(reportTapGesture)
    }

    @objc func authorTapped(_ sender: Any) {
        if let channelUrl = currentComment?.channelUrl,
           let url = LbryUri.tryParse(url: channelUrl, requireProto: false)
        {
            if UIApplication.currentViewController() as? FileViewController != nil {
                AppDelegate.shared.mainNavigationController?.popViewController(animated: false)
            }
            let vc = AppDelegate.shared.mainViewController?.storyboard?
                .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
            vc.claimUrl = url
            AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func fireReactionTapped(_ sender: Any) {
        if let currentComment {
            viewController?.react(currentComment, type: Helper.reactionTypeLike)
        }
    }

    @objc func slimeReactionTapped(_ sender: Any) {
        if let currentComment {
            viewController?.react(currentComment, type: Helper.reactionTypeDislike)
        }
    }

    @IBAction func replyCountTapped(_ sender: UIButton) {
        if let currentComment {
            viewController?.loadReplies(currentComment)
        }
    }

    @IBAction func replyTapped(_ sender: UIButton) {
        if let currentComment {
            viewController?.setReplyToComment(currentComment)
        }
    }

    @objc func blockChannelTapped(_ sender: Any) {
        if let mainVc = AppDelegate.shared.mainViewController as? MainViewController,
           let channelId = currentComment?.channelId,
           let channelName = currentComment?.channelName
        {
            let alert = UIAlertController(
                title: String(format: String.localized("Block %@?"), channelName),
                message: String(
                    format: String
                        .localized(
                            "Are you sure you want to block the comment author? You will no longer see comments nor content from %@."
                        ),
                    channelName,
                ),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: String.localized("Yes"), style: .default, handler: { _ in
                mainVc.addBlockedChannel(
                    claimId: channelId,
                    channelName: channelName,
                    notifyAfter: true
                )
            }))
            alert.addAction(UIAlertAction(title: String.localized("No"), style: .destructive))
            mainVc.present(alert, animated: true)
        }
    }

    @objc func reportContentTapped(_ sender: Any) {
        if let channelId = currentComment?.channelId,
           let commentId = currentComment?.commentId
        {
            if let url = URL(string: String(
                format: "https://odysee.com/$/report_content?claimId=%@&commentId=%@",
                channelId,
                commentId
            )) {
                let vc = SFSafariViewController(url: url)
                AppDelegate.shared.mainController.present(vc, animated: true, completion: nil)
            }
        }
    }
}
