//
//  NewContentService.swift
//  Ello
//
//  Created by Sean on 7/31/15.
//  Copyright (c) 2015 Ello. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

public struct NewContentNotifications {
    static let newNotifications = TypedNotification<NewContentService>(name: "NewNotificationsNotification")
    static let newStreamContent = TypedNotification<NewContentService>(name: "NewStreamContentNotification")
}

public class NewContentService {

    private struct Keys {
        static let FriendsNewContent = "friends-new-content-last-viewed-key"
        static let NoiseNewContent = "noise-new-content-last-viewed-key"
    }

    var timer: NSTimer?

    public init(){}

}

public extension NewContentService {

    public func startPolling() {
        timer?.invalidate()
        checkForNewContent()
        timer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(10.0), target: self, selector: Selector("checkForNewContent"), userInfo: nil, repeats: true)
    }

    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    @objc
    public func checkForNewContent() {
        checkForNewNotifications()
        checkForNewStreamContent()
    }

    public func updateCreatedAt(jsonables: [JSONAble], streamKind: StreamKind) {
        let old = NSDate(timeIntervalSince1970: 0)
        let new = newestDate(jsonables)
        let storedDate = Defaults[streamKind.lastViewedCreatedAtKey].date ?? old
        let mostRecent = new > storedDate ? new : storedDate
        Defaults[streamKind.lastViewedCreatedAtKey] = mostRecent
    }
}


private extension NewContentService {

    func newestDate(jsonables: [JSONAble]) -> NSDate {
        let old = NSDate(timeIntervalSince1970: 0)
        return jsonables.reduce(old) {
            (date, jsonable) -> NSDate in
            if let post = jsonable as? Post {
                return post.createdAt > date ? post.createdAt : date
            }
            else if let notification = jsonable as? Notification {
                return notification.createdAt > date ? notification.createdAt : date
            }
            else if let activity = jsonable as? Activity {
                return activity.createdAt > date ? activity.createdAt : date
            }
            return date
        }
    }

    func checkForNewNotifications() {
        let storedNotificationsDate = Defaults[StreamKind.Notifications(category: nil).lastViewedCreatedAtKey].date ?? NSDate(timeIntervalSince1970: 0)

        ElloProvider.elloRequest(
            ElloAPI.NotificationsNewContent(createdAt: storedNotificationsDate),
            success: { (_, responseConfig) in
                if let statusCode = responseConfig.statusCode where statusCode == 204 {
                    postNotification(NewContentNotifications.newNotifications, self)
                }
            },
            failure: nil
        )
    }

    func checkForNewStreamContent() {
        let storedFriendsDate = Defaults[Keys.FriendsNewContent].date ?? NSDate(timeIntervalSince1970: 0)

        ElloProvider.elloRequest(
            ElloAPI.FriendNewContent(createdAt: storedFriendsDate),
            success: { (_, responseConfig) in
                if let lastModified = responseConfig.lastModified {
                    Defaults[Keys.FriendsNewContent] = lastModified.toNSDate(formatter: HTTPDateFormatter)
                }

                if let statusCode = responseConfig.statusCode where statusCode == 204 {
                    postNotification(NewContentNotifications.newStreamContent, self)
                }
                else {
                    self.checkForNewNoiseContent()
                }
            },
            failure: nil
        )
    }

    func checkForNewNoiseContent() {
        let storedNoiseDate = Defaults[Keys.NoiseNewContent].date ?? NSDate(timeIntervalSince1970: 0)

        ElloProvider.elloRequest(
            ElloAPI.NoiseNewContent(createdAt: storedNoiseDate),
            success: { (_, responseConfig) in
                if let lastModified = responseConfig.lastModified {
                    Defaults[Keys.NoiseNewContent] = lastModified.toNSDate(formatter: HTTPDateFormatter)
                }

                if let statusCode = responseConfig.statusCode where statusCode == 204 {
                    postNotification(NewContentNotifications.newStreamContent, self)
                }
            },
            failure: nil
        )
    }
}