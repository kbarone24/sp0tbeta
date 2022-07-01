//
//  FriendRequestCollectionCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

protocol friendRequestCollectionCellDelegate: AnyObject{
    func deleteCell(sender: AnyObject?)
    func deleteFriendRequest(sender: AnyObject?)
    func acceptFriend(sender: AnyObject?)
}

class FriendRequestCollectionCell: UITableViewCell {
    
    weak var notificationDelegate: delegateProtocol?
    
    var itemHeight, itemWidth: CGFloat!

    var friendRequests: [UserNotification] = []
    
    var friendRequestCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewLayout.init())
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?){
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        itemWidth = UIScreen.main.bounds.width / 2.5
        itemHeight = itemWidth * 1.25
        self.backgroundColor = .systemYellow
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUpFriendRequests(friendRequests: [UserNotification]){
        self.friendRequests = friendRequests
    }
    
    func setUp(notifs: [UserNotification]) {
        
        ///hardcode cell height in case its laid out before view fully appears -> hard code body height so mask stays with cell change
        resetCell()
                
        friendRequests = notifs
        
        let requestLayout = UICollectionViewFlowLayout()
        requestLayout.scrollDirection = .horizontal
        requestLayout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        requestLayout.minimumInteritemSpacing = 8
        requestLayout.sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        
        friendRequestCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: itemHeight + 1)
        friendRequestCollection.backgroundColor = nil
        friendRequestCollection.delegate = self
        friendRequestCollection.dataSource = self
        friendRequestCollection.isScrollEnabled = true
        friendRequestCollection.setCollectionViewLayout(requestLayout, animated: false)
        friendRequestCollection.showsHorizontalScrollIndicator = false
        friendRequestCollection.register(FriendRequestCell.self, forCellWithReuseIdentifier: "FriendRequestCell")
        friendRequestCollection.translatesAutoresizingMaskIntoConstraints = true
        contentView.addSubview(friendRequestCollection)
        friendRequestCollection.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        friendRequestCollection.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        
    }
    
    func resetCell() {
        friendRequestCollection.removeFromSuperview()
    }
}

extension FriendRequestCollectionCell: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return friendRequests.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FriendRequestCell", for: indexPath) as? FriendRequestCell else { return UICollectionViewCell() }
        cell.collectionDelegate = self
        cell.setUp(notification: friendRequests[indexPath.row])
        //cell.globalRow = indexPath.row
        return cell
    }
}

extension FriendRequestCollectionCell: friendRequestCollectionCellDelegate{
    
    func deleteCell(sender: AnyObject?){
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.friendRequestCollection.performBatchUpdates({
                let cell = sender as! FriendRequestCell
                let indexPath = self.friendRequestCollection.indexPath(for: cell)
                var indexPaths: [IndexPath] = []
                indexPaths.append(indexPath!)
                self.friendRequests = self.notificationDelegate?.deleteFriendRequest(friendRequest: cell.friendRequest) ?? []
                self.friendRequestCollection.deleteItems(at: indexPaths)
                let friendID = cell.friendRequest.userInfo!.id
                //self.removeFriendRequest(friendID: friendID!, uid: uid)
            }) { (finished) in
                print("RELOADING")
                print("😩", self.friendRequestCollection)
                self.friendRequestCollection.reloadData()
                self.notificationDelegate?.reloadTable()
            }
            // Change `2.0` to the desired number of seconds.
           // Code you want to be delayed
        }
    }
    
    func deleteFriendRequest(sender: AnyObject?) {
        self.friendRequestCollection.performBatchUpdates({
            let cell = sender as! FriendRequestCell
            let indexPath = friendRequestCollection.indexPath(for: cell)
            var indexPaths: [IndexPath] = []
            indexPaths.append(indexPath!)
            friendRequests = notificationDelegate?.deleteFriendRequest(friendRequest: cell.friendRequest) ?? []
            friendRequestCollection.deleteItems(at: indexPaths)
            let friendID = cell.friendRequest.userInfo!.id
            //self.removeFriendRequest(friendID: friendID!, uid: uid)
        }) { (finished) in
            print("RELOADING")
            print("😩", self.friendRequestCollection)
            self.friendRequestCollection.reloadData()
            self.notificationDelegate?.reloadTable()
        }
        print("deleteting")
    }
    
    func acceptFriend(sender: AnyObject?) {
        let cell = sender as! FriendRequestCell
        let friendID = cell.friendRequest.userInfo!.id
        DispatchQueue.global(qos: .userInitiated).async { self.acceptFriendRequest(friendID: friendID!) }
    }
    
    
}
