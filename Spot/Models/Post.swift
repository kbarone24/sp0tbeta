//
//  MapPost.swift
//  Spot
//
//  Created by kbarone on 7/8/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import FirebaseFirestoreSwift
import FirebaseFirestore
import UIKit
import GeoFireUtils

struct Post: Identifiable, Codable {
    @DocumentID var id: String?
    var aspectRatios: [CGFloat]? = []
    var boostMultiplier: Double? = 1.0
    var caption: String
    var city: String? = ""
    var createdBy: String? = ""
    var commentCount: Int? = 0
    var dislikers: [String]? = []
    var friendsList: [String]? = []
    var g: String?
    var hiddenBy: [String]? = []
    var hideFromFeed: Bool? = false
    var imageURLs: [String]
    var videoURL: String?
    var inviteList: [String]? = []
    var likers: [String]
    var mapID: String? = ""
    var mapName: String? = ""
    var postLat: Double?
    var postLong: Double?
    var posterID: String
    var posterUsername: String? = ""
    var privacyLevel: String? = "friends"
    var reportedBy: [String]? = []
    var seenList: [String]? = []
    var spotID: String? = ""
    var spotLat: Double? = 0.0
    var spotLong: Double? = 0.0
    var spotName: String? = ""
    var spotPOICategory: String?
    var spotPrivacy: String? = ""
    var tag: String? = ""
    var taggedUserIDs: [String]? = []
    var taggedUsers: [String]? = []
    var timestamp: Timestamp

    var commentIDs: [String]? = []
    var commentLikeCounts: [Int]? = []
    var commentDislikeCounts: [Int]? = []
    var commentTimestamps: [Timestamp]? = []
    var commentPosterIDs: [String]? = []
    var commentReplyToIDs: [String]? = []

    var popID: String?
    var popName: String?

    // supplemental values for posts
    var parentPostID: String?
    var parentPosterID: String?
    var replyToUsername: String?
    var replyToID: String?
    var postChildren: [Post]? = []
    var lastCommentDocument: DocumentSnapshot?
    var userInfo: UserProfile?
    var mapInfo: CustomMap?
    var postImage: [UIImage] = []

    // supplemental values for replies
    var parentCommentCount = 0

    var postScore: Double? = 0
    var highlightCell = false
    var isLastPost = false

    var seen: Bool {
        let twoWeeks = Date().timeIntervalSince1970 - 86_400 * 14
        return (seenList?.contains(UserDataModel.shared.uid) ?? true) || timestamp.seconds < Int64(twoWeeks)
    }

    var seconds: Int64 {
        return timestamp.seconds
    }

    var coordinate: CLLocationCoordinate2D {
        return spotID ?? "" == "" ? CLLocationCoordinate2D(latitude: postLat ?? 0, longitude: postLong ?? 0) : CLLocationCoordinate2D(latitude: spotLat ?? 0, longitude: spotLong ?? 0)
    }

    var isVideo: Bool {
        return videoURL ?? "" != ""
    }

    var flagged: Bool {
        // 2 reports or 3 dislikes + dislikes > likes
        let dislikeCount = dislikers?.count ?? 0
        return reportedBy?.count ?? 0 > 1 || dislikeCount > 2 && dislikeCount > likers.count
    }

    enum CodingKeys: String, CodingKey {
        case id
        case aspectRatios
        case boostMultiplier
        case caption
        case city
        case commentCount
        case createdBy
        case dislikers
        case friendsList
        case g
        case hiddenBy
        case hideFromFeed
        case imageURLs
        case inviteList
        case likers
        case parentPostID
        case parentPosterID
        case postLat
        case postLong
        case posterID
        case posterUsername
        case privacyLevel
        case replyToUsername
        case replyToID
        case reportedBy
        case seenList
        case spotID
        case spotLat
        case spotLong
        case spotName
        case spotPOICategory
        case spotPrivacy
        case taggedUserIDs
        case taggedUsers
        case timestamp
        case videoURL

        case mapID
        case mapName

        case commentIDs
        case commentLikeCounts
        case commentDislikeCounts
        case commentTimestamps
        case commentPosterIDs
        case commentReplyToIDs

        case popID
        case popName
    }

    init(
        postImage: UIImage?,
        caption: String,
        coordinate: CLLocationCoordinate2D,
        spot: Spot?,
        map: CustomMap?
    ) {
        var aspectRatios = [CGFloat]()
        if let postImage {
            let aspectRatio = min((postImage.size.height / postImage.size.width), UserDataModel.shared.maxAspect)
            aspectRatios.append(aspectRatio)
            self.postImage = [postImage]
        }

        self.id = UUID().uuidString
        self.aspectRatios = aspectRatios
        self.boostMultiplier = 1
        self.caption = caption
        self.city = spot?.city ?? ""
        self.commentCount = 0
        self.createdBy = spot?.founderID ?? ""
        self.dislikers = []
        self.g = GFUtils.geoHash(forLocation: coordinate)
        self.imageURLs = []
        self.inviteList = map?.memberIDs ?? []
        self.likers = []
        self.mapID = map?.id ?? ""
        self.mapName = map?.mapName ?? ""
        self.postLat = coordinate.latitude
        self.postLong = coordinate.longitude
        self.posterID = UserDataModel.shared.uid
        self.posterUsername = UserDataModel.shared.userInfo.username
        self.seenList = []
        self.spotID = spot?.id ?? ""
        self.spotLat = spot?.spotLat ?? 0.0
        self.spotLong = spot?.spotLong ?? 0.0
        self.spotName = spot?.spotName ?? ""
        self.spotPOICategory = spot?.poiCategory ?? ""
        self.spotPrivacy = spot?.privacyLevel ?? ""
        self.timestamp = Timestamp(date: Date())
        self.videoURL = ""

        let secretMap = map?.secret ?? false
        self.privacyLevel = secretMap ? "invite" : "public"
        self.hideFromFeed = secretMap

        var friendsList = [UserDataModel.shared.uid]
        if secretMap {
            friendsList += map?.memberIDs ?? []
        } else {
            // show to map members, friends, spot members
            friendsList += map?.likers ?? [] +
            UserDataModel.shared.userInfo.friendIDs +
            (spot?.visitorList ?? [])
        }
        self.friendsList = friendsList.removingDuplicates()

        self.userInfo = UserDataModel.shared.userInfo
        self.highlightCell = true
    }

    init(
        id: String,
        posterID: String,
        postDraft: PostDraft,
        mapInfo: CustomMap?,
        actualTimestamp: Timestamp,
        uploadImages: [UIImage],
        imageURLs: [String],
        aspectRatios: [CGFloat],
        likers: [String]
    ) {
        self.id = id
        self.aspectRatios = aspectRatios
        self.caption = postDraft.caption ?? ""
        self.city = postDraft.city
        self.createdBy = postDraft.createdBy
        self.friendsList = postDraft.friendsList ?? []
        self.hideFromFeed = postDraft.hideFromFeed
        self.imageURLs = imageURLs
        self.inviteList = postDraft.inviteList ?? []
        self.likers = likers
        self.postLat = postDraft.postLat
        self.postLong = postDraft.postLong
        self.posterID = posterID
        self.posterUsername = UserDataModel.shared.userInfo.username
        self.privacyLevel = postDraft.privacyLevel ?? ""
        self.seenList = []
        self.spotID = postDraft.spotID ?? ""
        self.spotLat = postDraft.spotLat
        self.spotLong = postDraft.spotLong
        self.spotName = postDraft.spotName
        self.spotPrivacy = postDraft.spotPrivacy
        self.spotPOICategory = postDraft.poiCategory
        self.tag = ""
        self.taggedUserIDs = postDraft.taggedUserIDs ?? []
        self.taggedUsers = postDraft.taggedUsers ?? []
        self.timestamp = actualTimestamp
        self.userInfo = UserDataModel.shared.userInfo
        self.mapInfo = mapInfo
        self.postImage = uploadImages
        self.postScore = 0
    }

    init(spotID: String, spotName: String, mapID: String, mapName: String) {
        self.posterUsername = UserDataModel.shared.userInfo.username
        self.id = UUID().uuidString
        self.spotID = spotID
        self.spotName = spotName
        self.caption = ""
        self.friendsList = []
        self.imageURLs = []
        self.likers = []
        self.postLat = 0
        self.postLong = 0
        self.timestamp = Timestamp(date: Date())
        self.mapInfo = nil
        self.postImage = []
        self.postScore = 0
        self.posterID = ""
    }

    init(
        posterUsername: String,
        caption: String,
        privacyLevel: String,
        longitude: Double,
        latitude: Double,
        timestamp: Timestamp
    ) {
        self.id = UUID().uuidString
        self.posterUsername = posterUsername
        self.posterID = UserDataModel.shared.uid
        self.privacyLevel = privacyLevel
        self.postLat = latitude
        self.postLong = longitude
        self.timestamp = timestamp
        self.caption = caption
        self.likers = []
        self.imageURLs = []
        self.mapInfo = nil
        self.postImage = []
        self.postScore = 0
        self.friendsList = []
    }
}

extension Post {
    func getSpotPostScore() -> Double {
        let postScore = getBasePostScore(likeCount: nil, dislikeCount: nil, passedCommentCount: nil, feedMode: true)
        let boost = max(boostMultiplier ?? 1, 0.0001)
        let finalScore = postScore * boost
        return finalScore
    }

    func getBasePostScore(likeCount: Int?, dislikeCount: Int?, passedCommentCount: Int?, feedMode: Bool) -> Double {
        let feedMode = likeCount == nil
        var postScore: Double = 10

        let likeCount = feedMode ? Double(likers.filter({ $0 != posterID }).count) : Double(likeCount ?? 0)
        let dislikeCount = feedMode ? Double(dislikers?.count ?? 0) : Double(dislikeCount ?? 0)
        let commentCount = feedMode ? Double(commentCount ?? 0) : Double(passedCommentCount ?? 0)

     //   postScore += commentCount * 25
        postScore += likeCount > 2 ? 100 : 0

        let postTime = Double(timestamp.seconds)
        let current = Date().timeIntervalSince1970
        let currentTime = Double(current)
        let timeSincePost = currentTime - postTime

        // ideally, last hour = 1100, today = 650, last week = 200
        let maxFactor: Double = 55
        let factor = min(1 + (1_000_000 / timeSincePost), maxFactor)
        let timeMultiplier: Double = feedMode ? 3 : 20

        var timeScore = factor * timeMultiplier
        if !feedMode {
            timeScore += pow(1.12, factor)
        }
        postScore += timeScore

        // multiply by ratio of likes / people who have seen it. Meant to give new posts with a couple likes a boost
        // weigh dislikes as 2x worse than likes
        let maxLikeAdjust: Double = feedMode ? 10 : 3
        let likesNetDislikes = likeCount + commentCount / 2 - dislikeCount * 2
        let likeMultiplier = min(maxLikeAdjust, 1 + (likesNetDislikes) / 10)
        postScore *= likeMultiplier
        return postScore
    }
}

extension [Post] {
    // call to always have opened post be first in content viewer
    mutating func sortPostsOnOpen(index: Int) {
        var i = 0
        while i < index {
            let element = remove(at: 0)
            append(element)
            i += 1
        }
    }
}

extension Post: Hashable {
    static func == (lhs: Post, rhs: Post) -> Bool {
        return lhs.id == rhs.id &&
        lhs.boostMultiplier == rhs.boostMultiplier &&
        lhs.aspectRatios == rhs.aspectRatios &&
        lhs.caption == rhs.caption &&
        lhs.commentCount == rhs.commentCount &&
        lhs.dislikers == rhs.dislikers &&
        lhs.hiddenBy == rhs.hiddenBy &&
        lhs.imageURLs == rhs.imageURLs &&
        lhs.videoURL == rhs.videoURL &&
        lhs.likers == rhs.likers &&
        lhs.posterID == rhs.posterID &&
        lhs.posterUsername == rhs.posterUsername &&
        lhs.privacyLevel == rhs.privacyLevel &&
  //      lhs.seenList == rhs.seenList &&
        lhs.spotID == rhs.spotID &&
        lhs.spotLat == rhs.spotLat &&
        lhs.spotLong == rhs.spotLong &&
        lhs.spotName == rhs.spotName &&
        lhs.spotPOICategory == rhs.spotPOICategory &&
        lhs.spotPrivacy == rhs.spotPrivacy &&
        lhs.taggedUserIDs == rhs.taggedUserIDs &&
        lhs.timestamp == rhs.timestamp &&
        lhs.userInfo == rhs.userInfo &&
        lhs.postImage == rhs.postImage &&
        lhs.postScore == rhs.postScore &&
        lhs.parentCommentCount == rhs.parentCommentCount &&
        lhs.postChildren == rhs.postChildren &&
        lhs.isLastPost == rhs.isLastPost
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(aspectRatios)
        hasher.combine(boostMultiplier)
        hasher.combine(caption)
        hasher.combine(commentCount)
        hasher.combine(hiddenBy)
        hasher.combine(imageURLs)
        hasher.combine(videoURL)
        hasher.combine(likers)
        hasher.combine(postLat)
        hasher.combine(postLong)
        hasher.combine(posterID)
        hasher.combine(posterUsername)
        hasher.combine(privacyLevel)
        hasher.combine(spotID)
        hasher.combine(spotLat)
        hasher.combine(spotLong)
        hasher.combine(spotName)
        hasher.combine(spotPOICategory)
        hasher.combine(spotPrivacy)
        hasher.combine(timestamp)
        hasher.combine(userInfo)
        hasher.combine(postScore)
        hasher.combine(parentCommentCount)
        hasher.combine(postChildren)
        hasher.combine(isLastPost)
    }
}

extension Post {
    mutating func setTaggedUsers() {
        let taggedUsers = caption.getTaggedUsers()
        let usernames = taggedUsers.map({ $0.username })
        self.taggedUsers = usernames
        self.taggedUserIDs = taggedUsers.map({ $0.id ?? "" })
    }
}
