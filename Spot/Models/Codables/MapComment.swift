//
//  MapComment.swift
//  Spot
//
//  Created by kbarone on 7/22/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseFirestoreSwift

struct MapComment: Identifiable, Codable {
    
    @DocumentID var id: String?
    var comment: String
    var commenterID: String
    var taggedUsers: [String]? = []
    var timestamp: Firebase.Timestamp
    var likers: [String]? = []
    
    var userInfo: UserProfile?
    var feedHeight: CGFloat = 0
    var seconds: Int64 {
        return timestamp.seconds
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case comment
        case commenterID
        case likers
        case taggedUsers
        case timestamp
    }
}
