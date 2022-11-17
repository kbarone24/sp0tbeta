//
//  MapsCollectionExtension.swift
//  Spot
//
//  Created by Kenny Barone on 7/21/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseUI
import Foundation
import Mixpanel
import UIKit

extension MapController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if postsFetched {
            // adjust for user in chapel hill
            let extraCells = userInChapelHill() ? 3 : 2
            return UserDataModel.shared.userInfo.mapsList.count + extraCells
        }
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if !userLoaded, let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MapLoadingCell", for: indexPath) as? MapLoadingCell {
            // display loading cell
            return cell
        }
        if userInChapelHill(), indexPath.row == UserDataModel.shared.userInfo.mapsList.count + 1,
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CampusMapCell", for: indexPath) as? CampusMapCell {
            return cell
        }
        let addMapIncrement = userInChapelHill() ? 2 : 1
        if indexPath.row == UserDataModel.shared.userInfo.mapsList.count + addMapIncrement,
           let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddMapCell", for: indexPath) as? AddMapCell {
            // display new map button
            return cell
        }

        if indexPath.row == 0, let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FriendsCell", for: indexPath) as? FriendsMapCell {
            var avatarURLs = friendsPostsDictionary.values.map({ $0.userInfo?.avatarURL ?? "" }).uniqued().prefix(5)
            if avatarURLs.count < 5 && !avatarURLs.contains(UserDataModel.shared.userInfo.avatarURL ?? "") { avatarURLs.append(UserDataModel.shared.userInfo.avatarURL ?? "") }
            cell.setUp(avatarURLs: Array(avatarURLs))
            cell.isSelected = selectedItemIndex == indexPath.row
            return cell
        }

        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MapCell", for: indexPath) as? MapHomeCell {
            let map = UserDataModel.shared.userInfo.mapsList[indexPath.row - 1]
            let postsList = map.postsDictionary.map({ $0.value })
            cell.setUp(map: map, postsList: postsList)
            cell.isSelected = selectedItemIndex == indexPath.row
            return cell
        }
        return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let addMapIncrement = userInChapelHill() ? 2 : 1
        if userInChapelHill(), indexPath.item == UserDataModel.shared.userInfo.mapsList.count + 1 {
            openExploreMaps(onboarding: false)
            return
        } else if indexPath.item == UserDataModel.shared.userInfo.mapsList.count + addMapIncrement {
            // launch new map
            openNewMap()
            return
        } else if indexPath.item == selectedItemIndex {
            openSelectedMap()
            return
        }
        HapticGenerator.shared.play(.light)
        DispatchQueue.main.async {
            self.selectItemAt(index: indexPath.row)
        }
    }

    func selectItemAt(index: Int) {
        mapsCollection.selectItem(at: IndexPath(item: index, section: 0), animated: true, scrollPosition: [])
        self.selectMapAt(index: index)
    }

    func selectMapAt(index: Int) {
        Mixpanel.mainInstance().track(event: "MapControllerSelectMapAt", properties: ["index": index])
        if index != self.selectedItemIndex {
            self.selectedItemIndex = index
            self.setNewPostsButtonCount()
            self.addMapAnnotations(index: index, reload: false)
            self.addFriendsView.removeFromSuperview()
            if index != 0 { UserDataModel.shared.userInfo.mapsList[index - 1].selected.toggle() }
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing: CGFloat = 9 + 5 * 3
        let itemWidth = (UIScreen.main.bounds.width - spacing) / 3.25
        let itemHeight: CGFloat = 95
        let firstItemWidth = itemWidth * 1.05

        if postsFetched {
            if indexPath.item == 0 {
                // friends cell
                return CGSize(width: firstItemWidth, height: itemHeight)
            }
            // standard cell
            return CGSize(width: itemWidth, height: itemHeight)
        }
        // loading indicator
        return CGSize(width: UIScreen.main.bounds.width, height: itemHeight)
    }

    func addMapAnnotations(index: Int, reload: Bool) {
        mapView.removeAllAnnos()
        let map = getSelectedMap() ?? getFriendsMapObject()
        // create temp map to represent friends map
        for group in map.postGroup { mapView.addSpotAnnotation(group: group, map: map) }

        if !reload {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { [weak self] in
                guard let self = self else { return }
                self.centerMapOnMapPosts(animated: false)
            })
        }
    }

    func getFriendsMapObject() -> CustomMap {
        var map = CustomMap(founderID: "", imageURL: "", likers: [], mapName: "", memberIDs: [], posterIDs: [], posterUsernames: [], postIDs: [], postImageURLs: [], secret: false, spotIDs: [])
        map.postsDictionary = friendsPostsDictionary
        map.postGroup = postGroup
        return map
    }
}
