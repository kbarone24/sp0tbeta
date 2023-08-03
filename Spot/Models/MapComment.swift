//
//  MapComment.swift
//  Spot
//
//  Created by kbarone on 7/22/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestoreSwift
import FirebaseFirestore
import UIKit

struct MapComment: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var comment: String
    var commenterID: String
    var commenterUsername: String?
    var taggedUsers: [String]? = []
    var timestamp: Timestamp
    var likers: [String]? = []

    var userInfo: UserProfile?
    var seconds: Int64 {
        return timestamp.seconds
    }

    enum CodingKeys: String, CodingKey {
        case id
        case comment
        case commenterID
        case commenterUsername
        case likers
        case taggedUsers
        case timestamp
    }
}
