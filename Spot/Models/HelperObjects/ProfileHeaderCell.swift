//
//  ProfileHeaderCell.swift
//  Spot
//
//  Created by Arnold on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit

enum ProfileRelation {
    case myself
    case friend
    case pending
    case stranger
    case received
}

class ProfileHeaderCell: UICollectionViewCell {
    
    private var profileImage: UIImageView!
    private var profileAvatar: UIImageView!
    private var profileName: UILabel!
    private var profileAccount: UILabel!
    private var locationButton: UIButton!
    public var friendListButton: UIButton!
    public var actionButton: UIButton!
    private var profileID: String = ""
    private var relation: ProfileRelation!
    private var pendingFriendNotiID: String?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        
    }
    
    public func cellSetup(profileID: String, profileURL: String, avatarURL: String, name: String, account: String, location: String, friendsCount: Int, relation: ProfileRelation, pendingFriendNotiID: String?) {
        self.profileID = profileID
        profileImage.sd_setImage(with: URL(string: profileURL))
        profileAvatar.sd_setImage(with: URL(string: avatarURL)) { image, Error, cache, url  in
            self.profileAvatar.image = image?.withHorizontallyFlippedOrientation()
        }
        profileName.text = name
        profileAccount.text = account
        locationButton.setTitle(location, for: .normal)
        if location == "" {
            locationButton.setImage(UIImage(), for: .normal)
            friendListButton.snp.updateConstraints {
                $0.leading.equalTo(locationButton.snp.trailing)
            }
        }
        friendListButton.setTitle("\(friendsCount) friends", for: .normal)
        self.relation = relation
        self.pendingFriendNotiID = pendingFriendNotiID
        switch relation {
        case .myself:
            actionButton.setTitle("Edit profile", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        case .friend:
            actionButton.setImage(UIImage(named: "FriendsIcon"), for: .normal)
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle("Friends", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        case .pending:
            actionButton.setImage(UIImage(named: "FriendsPendingIcon"), for: .normal)
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle("Pending", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        case .stranger, .received:
            actionButton.setImage(UIImage(named: "AddFriendIcon"), for: .normal)
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle(relation == .stranger ? "Add friend" : "Accept friend request", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
        }
        actionButton.addTarget(self, action: #selector(actionButtonAction), for: .touchUpInside)
        actionButton.setTitleColor(.black, for: .normal)
    }
}

extension ProfileHeaderCell {
    private func viewSetup() {
        contentView.backgroundColor = .white
        
        profileImage = UIImageView {
            $0.image = UIImage()
            $0.contentMode = .scaleAspectFit
            $0.layer.masksToBounds = true
            $0.backgroundColor = .gray
            contentView.addSubview($0)
        }
        profileImage.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.equalToSuperview().offset(28)
            $0.width.height.equalTo(84)
        }
        profileImage.layer.cornerRadius = 84 / 2

        profileAvatar = UIImageView {
            $0.image = UIImage()
            $0.contentMode = .scaleAspectFit
            contentView.addSubview($0)
        }
        profileAvatar.snp.makeConstraints {
            $0.leading.equalTo(profileImage).inset(-14)
            $0.bottom.equalTo(profileImage).inset(-8.24)
            $0.height.equalTo(47.25)
            $0.width.equalTo(36)
        }
        
        profileName = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.text = ""
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
        profileName.snp.makeConstraints {
            $0.leading.equalTo(profileImage.snp.trailing).offset(15)
            $0.top.equalTo(profileImage).offset(7)
            $0.height.equalTo(23)
            $0.trailing.equalToSuperview().inset(29)
        }
        
        profileAccount = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            $0.text = ""
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
        profileAccount.snp.makeConstraints {
            $0.leading.equalTo(profileName).offset(2)
            $0.top.equalTo(profileName.snp.bottom).offset(2)
            $0.height.equalTo(19)
            $0.width.equalTo(113)
        }
        
        locationButton = UIButton {
            $0.setImage(UIImage(named: "ProfileLocation"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.titleLabel?.adjustsFontSizeToFitWidth = true
            $0.setTitleColor(UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1), for: .normal)
            $0.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
            $0.addTarget(self, action: #selector(locationButtonAction), for: .touchUpInside)
            contentView.addSubview($0)
        }
        locationButton.snp.makeConstraints {
            $0.leading.equalTo(profileAccount)
            $0.top.equalTo(profileAccount.snp.bottom).offset(1)
            $0.height.equalTo(38)
        }
        
        friendListButton = UIButton {
            $0.setImage(UIImage(named: "Friends"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.titleLabel?.adjustsFontSizeToFitWidth = true
            $0.setTitleColor(UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1), for: .normal)
            $0.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
            contentView.addSubview($0)
        }
        friendListButton.snp.makeConstraints {
            $0.leading.equalTo(locationButton.snp.trailing).offset(15)
            $0.top.equalTo(locationButton)
            $0.trailing.lessThanOrEqualToSuperview()
            $0.height.equalTo(38)
        }
        
        actionButton = UIButton {
            $0.setTitle("Edit profile", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
            contentView.addSubview($0)
        }
        actionButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.height.equalTo(37)
            $0.top.equalTo(profileImage.snp.bottom).offset(16)
        }
        actionButton.layer.cornerRadius = 37 / 2
    }
    
    @objc func actionButtonAction() {
        switch relation {
        case .myself:
            UIView.animate(withDuration: 0.15) {
                self.actionButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            } completion: { (Bool) in
                UIView.animate(withDuration: 0.15) {
                    self.actionButton.transform = .identity
                }
            }
        case .friend:
            print("Friend")
        case .pending, .received:
            if pendingFriendNotiID != nil {
                relation == .pending ? removeFriendRequest(friendID: profileID, notificationID: pendingFriendNotiID!) : acceptFriendRequest(friendID: profileID, notificationID: pendingFriendNotiID!)
                actionButton.setImage(UIImage(named: "FriendsIcon"), for: .normal)
                actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
                actionButton.setTitle("Friends", for: .normal)
                actionButton.setTitleColor(.black, for: .normal)
                actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            }
        case .stranger:
            addFriend(senderProfile: UserDataModel.shared.userInfo, receiverID: profileID)
            actionButton.setImage(UIImage(named: "FriendsPendingIcon"), for: .normal)
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle("Pending", for: .normal)
            actionButton.setTitleColor(.black, for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        case .none:
            return
        }
    }
    
    @objc func locationButtonAction() {
    }
}
