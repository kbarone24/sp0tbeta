//
//  FriendRequestCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseUI
import Foundation
import Mixpanel
import UIKit

class FriendRequestCell: UICollectionViewCell {
    var friendRequest: UserNotification?
    weak var collectionDelegate: FriendRequestCollectionCellDelegate?
    weak var notificationControllerDelegate: NotificationsDelegate?

    private lazy var activityIndicator = UIActivityIndicatorView()
    private lazy var profilePic: UIImageView = {
        let view = UIImageView()
        view.layer.masksToBounds = false
        view.layer.cornerRadius = self.frame.width / 4
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.isUserInteractionEnabled = true
        return view
    }()
    private lazy var avatarImage: UIImageView = {
        let view = UIImageView()
        view.layer.masksToBounds = true
        view.contentMode = UIView.ContentMode.scaleAspectFill
        return view
    }()

    private lazy var senderUsername: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        return label
    }()

    private lazy var timestamp: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Regular", size: 14.5)
        label.textColor = UIColor(red: 0.696, green: 0.696, blue: 0.696, alpha: 1)
        return label
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "CancelButtonGray"), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    private lazy var acceptButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1).cgColor
        button.setImage(UIImage(named: "AddFriendIcon"), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)
        let title = NSMutableAttributedString(string: "Accept", attributes: [
            NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15) as Any,
            NSAttributedString.Key.foregroundColor: UIColor.black
        ])
        button.setAttributedTitle(title, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var confirmButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1).cgColor
        button.setImage(UIImage(named: "ProfileFriendsIcon"), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)

        let customButtonTitle = NSMutableAttributedString(string: "Confirmed", attributes: [
            NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15) as Any,
            // NSAttributedString.Key.backgroundColor: UIColor.red,
            NSAttributedString.Key.foregroundColor: UIColor.black
        ])
        button.setAttributedTitle(customButtonTitle, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUpView() {
        profilePic.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(profileTap)))
        contentView.addSubview(profilePic)
        profilePic.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(24)
            $0.height.width.equalTo(self.frame.width / 2)
        }

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(profilePic.snp.leading).offset(-3)
            $0.bottom.equalTo(profilePic.snp.bottom).offset(3)
            $0.width.equalTo(self.frame.width * 0.12)
            $0.height.equalTo((self.frame.width * 0.12) * 1.7)
        }

        senderUsername.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.profileTap)))
        contentView.addSubview(senderUsername)
        senderUsername.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(profilePic.snp.bottom).offset(12)
            $0.height.lessThanOrEqualTo(18)
        }

        contentView.addSubview(timestamp)
        timestamp.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-8)
            $0.top.equalToSuperview().offset(10)
        }

        acceptButton.addTarget(self, action: #selector(acceptTap), for: .touchUpInside)
        contentView.addSubview(acceptButton)
        acceptButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.top.equalTo(senderUsername.snp.bottom).offset(18)
            $0.bottom.equalToSuperview().offset(-11)
        }

        contentView.addSubview(confirmButton)
        confirmButton.snp.makeConstraints {
            $0.edges.equalTo(acceptButton)
        }

        closeButton.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
        contentView.addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.top.equalToSuperview()
            $0.width.height.equalTo(32)
        }
    }

    func setValues(notification: UserNotification) {
        self.friendRequest = notification
        self.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        self.layer.cornerRadius = 14

        let url = friendRequest?.userInfo?.imageURL ?? ""
        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        profilePic.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])

        let avatarURL = notification.userInfo?.avatarURL ?? ""
        if avatarURL != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFill)
            avatarImage.sd_setImage(with: URL(string: avatarURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }
        senderUsername.text = friendRequest?.userInfo?.username
        timestamp.text = friendRequest?.timestamp.toString(allowDate: false) ?? ""
    }

    @objc func profileTap() {
        Mixpanel.mainInstance().track(event: "NotificationsFriendRequestUserTap")
        collectionDelegate?.getProfile(userProfile: friendRequest?.userInfo ?? UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: ""))
    }

    @objc func cancelTap() {
        Mixpanel.mainInstance().track(event: "NotificationsFriendRequestRemoved")
        collectionDelegate?.deleteFriendRequest(sender: self)
    }

    @objc func acceptTap() {
        Mixpanel.mainInstance().track(event: "NotificationsFriendRequestAccepted")
        acceptButton.isHidden = true
        confirmButton.isHidden = false
        collectionDelegate?.acceptFriend(sender: self)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        profilePic.sd_cancelCurrentImageLoad()
        avatarImage.sd_cancelCurrentImageLoad()
    }

    func addActivityIndicator() {
        bringSubviewToFront(activityIndicator)
        activityIndicator.startAnimating()
    }

    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
    }
}
