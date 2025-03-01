//
//  FriendRequestCollectionCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseAuth
import UIKit

protocol FriendRequestCollectionDelegate: AnyObject {
    func friendRequestCellProfileTap(userProfile: UserProfile)
    func deleteFriendRequest(friendRequest: UserNotification) -> [UserNotification]
    func reloadTable()
}

class FriendRequestCollectionCell: UITableViewCell {
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    weak var delegate: FriendRequestCollectionDelegate?
    private lazy var friendRequests: [UserNotification] = []

    private let itemHeight: CGFloat = 201
    private let itemWidth: CGFloat = 181

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)

        // same as with tableView, it acts up if I set up the view using the other style
        let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        collectionView.backgroundColor = nil
        collectionView.isScrollEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(FriendRequestCell.self, forCellWithReuseIdentifier: "FriendRequestCell")
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        return collectionView
    }()
    
    lazy var friendService: FriendsServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.friendsService)
        return service
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none

        collectionView.delegate = self
        collectionView.dataSource = self
        contentView.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUpFriendRequests(friendRequests: [UserNotification]) {
        self.friendRequests = friendRequests
    }

    func setValues(notifications: [UserNotification]) {
        friendRequests = notifications
    }
}

// MARK: delegate and data source protocol
extension FriendRequestCollectionCell: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return friendRequests.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FriendRequestCell", for: indexPath) as? FriendRequestCell, let friendRequest = friendRequests[safe: indexPath.row] else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
        }
        cell.collectionDelegate = self
        cell.setValues(notification: friendRequest)
        // cell.globalRow = indexPath.row
        return cell
    }
}

// MARK: friendRequestCollectionCellDelegate
extension FriendRequestCollectionCell: FriendRequestCellDelegate {
    func deleteFriendRequest(sender: AnyObject?, accepted: Bool) {
        guard let cell = sender as? FriendRequestCell,
              let indexPath = collectionView.indexPath(for: cell),
                let friendRequest = cell.friendRequest else { return }

        collectionView.performBatchUpdates(({
            let indexPaths = [indexPath]
            friendRequests = delegate?.deleteFriendRequest(friendRequest: friendRequest) ?? []
            collectionView.deleteItems(at: indexPaths)
            let friendID = friendRequest.userInfo?.id ?? ""
            let notiID = friendRequest.id ?? ""
            if !accepted {
                self.friendService?.removeFriendRequest(friendID: friendID, notificationID: notiID)
            }

        }), completion: { _ in
            self.collectionView.reloadData()
            self.delegate?.reloadTable()
        })
    }

    func getProfile(userProfile: UserProfile) {
        delegate?.friendRequestCellProfileTap(userProfile: userProfile)
    }

    func acceptFriend(friend: UserProfile, notiID: String) {
        DispatchQueue.global(qos: .userInitiated).async { self.friendService?.acceptFriendRequest(friend: friend, notificationID: notiID)
        }
    }
}
