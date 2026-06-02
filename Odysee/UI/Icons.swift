//
//  Icons.swift
//  Odysee
//
//  Created by Keith on 27/05/2026.
//

import Foundation

enum Icons {
    static let re = if #available(iOS 18, *) {
        "arrow.trianglehead.2.clockwise.rotate.90"
    } else {
        "arrow.triangle.2.circlepath"
    }

    static let follow = "heart"
    static let unfollow = "heart.slash.fill"
    static let enableNotifications = "bell.fill"
    static let disableNotifications = "bell.slash.fill"

    static let expand = "chevron.down"
    static let shrink = "chevron.up"

    static let pause = "pause.fill"
    static let play = "play.fill"

    static let claimChannel = "at"
    static let claimVideo = "video"
    static let claimLivestream = "web.camera"
    static let claimImage = "photo"
    static let claimAudio = "headphones"
    static let claimDocument = "text.document"
    static let claimOther = "arrow.down"
    static let claimRepost = re
    static let claimCollection = if #available(iOS 16.1, *) {
        "play.square.stack"
    } else {
        "list.and.film"
    }

    static let livestreamViewers = "eye.fill"

    static let edit = "pencil"

    static let publish = "icloud.and.arrow.up"

    static let remove = "xmark"
    static let add = "plus"

    static let delete = "trash"

    static let rewardVerificationHelp = "questionmark.circle"
    static let closeCancelSkip = "xmark"

    static let youtubeSyncCompleted = "checkmark.circle"
    static let youtubeSyncIncomplete = "circle"

    static let notificationSubscription = "heart.fill"
    static let notification = "star"
}
