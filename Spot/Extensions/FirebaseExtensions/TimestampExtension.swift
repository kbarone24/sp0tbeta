//
//  TimestampExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/14/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseFirestore
import Firebase

extension Timestamp {
    func toString(allowDate: Bool) -> String {
        let seconds = self.seconds
        let current = Date().timeIntervalSince1970
        let currentTime = Int64(current)
        let timeSincePost = currentTime - seconds

        if timeSincePost > 604_800 && allowDate {
            // return date
            let timeInterval = TimeInterval(integerLiteral: seconds)
            let date = Date(timeIntervalSince1970: timeInterval)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            return dateString
        } else {
            // return time since post
            if timeSincePost <= 3_600 {
                let minutes = max(timeSincePost / 60, 1)
                return "\(minutes)m"

            } else if timeSincePost <= 86_400 {
                let hours = timeSincePost / 3_600
                return "\(hours)h"

            } else if timeSincePost <=  31_536_000 {
                let days = timeSincePost / 86_400
                return "\(days)d"

            } else {
                let years = timeSincePost / 31_536_000
                return "\(years)y"
            }
        }
    }
}
