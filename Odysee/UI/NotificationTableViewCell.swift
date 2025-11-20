//
//  NotificationTableViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/12/2020.
//

import UIKit

class NotificationTableViewCell: UITableViewCell {
    @IBOutlet var iconView: UIImageView!
    @IBOutlet var avatarView: UIImageView!
    @IBOutlet var titleView: UILabel!
    @IBOutlet var bodyView: UILabel!
    @IBOutlet var timeView: UILabel!
    @IBOutlet var unreadIndicatorView: UIView!

    var currentNotification: LbryNotification?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func displayAuthorImage() {
        if let thumbnail = currentNotification?.notificationParameters?.dynamic?.commentAuthorThumbnail,
           !thumbnail.isBlank,
           let thumbnailUrl = URL(string: thumbnail)
        {
            avatarView.backgroundColor = UIColor.clear
            avatarView.load(url: thumbnailUrl)
        }
    }

    func setNotification(notification: LbryNotification) {
        if currentNotification != nil, notification.id != currentNotification!.id {
            iconView.isHidden = true
            avatarView.isHidden = true
            iconView.image = nil
            iconView.tintColor = UIColor.clear
            avatarView.image = nil
            avatarView.backgroundColor = UIColor.clear
        }

        currentNotification = notification
        unreadIndicatorView.layer.cornerRadius = 6
        unreadIndicatorView.isHidden = notification.isRead ?? true
        if let _ = currentNotification?.notificationParameters?.dynamic?.commentAuthorThumbnail {
            iconView.isHidden = true
            avatarView.isHidden = false

            avatarView.rounded()
            avatarView.image = UIImage(named: "spaceman")
            avatarView.backgroundColor = Helper.lightPrimaryColor
            displayAuthorImage()
        } else {
            iconView.isHidden = false
            avatarView.isHidden = true

            if notification.notificationRule == "first_subscription" || notification
                .notificationRule == "creator_subscriber"
            {
                iconView.image = UIImage(systemName: "heart.fill")
                iconView.tintColor = UIColor.systemRed
            } else {
                iconView.image = UIImage(systemName: "star")
                iconView.tintColor = Helper.primaryColor
            }
        }

        titleView.text = notification.title ?? ""
        bodyView.text = notification.text ?? ""
        if let date = Helper.apiDateFormatter.date(from: notification.createdAt ?? "") {
            let localDateString = Helper.localDateFormatter.string(from: date)
            let localDate = Helper.localDateFormatter.date(from: localDateString)
            timeView.text = Helper.fullRelativeDateFormatter.localizedString(for: localDate!, relativeTo: Date())
        }
    }
}
