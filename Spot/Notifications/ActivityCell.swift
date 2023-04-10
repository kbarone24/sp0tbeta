//
//  ActivityCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/26/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//
import Firebase
import Mixpanel
import UIKit
import SDWebImage
import FirebaseFirestore

class ActivityCell: UITableViewCell {
    weak var notificationControllerDelegate: NotificationsDelegate?
    lazy var notification: UserNotification = .init(seen: false, senderID: "", timestamp: Timestamp(), type: "")

    private lazy var avatarImage: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = true
        view.contentMode = .scaleAspectFit
        return view
    }()

    private lazy var username: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
        return label
    }()

    private lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private lazy var postImage: UIImageView = {
        let view = UIImageView()
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        return view
    }()

    private lazy var subtitle = ""
    private lazy var time = ""

    private lazy var detailOriginalWidth: CGFloat = 0
    private lazy var detailOriginalHeight: CGFloat = 0

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        setUpView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUpView() {
        contentView.addSubview(avatarImage)
        avatarImage.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(profileTap)))
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(12)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(40.5)
            $0.width.equalTo(36)
        }

        contentView.addSubview(postImage)
        // make constriats once we know noti type

        contentView.addSubview(username)
        username.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(profileTap)))
        username.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(8)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints {
            $0.top.equalTo(username.snp.bottom)
            $0.leading.equalTo(avatarImage.snp.trailing).offset(7)
            $0.trailing.equalTo(postImage.snp.leading).offset(-10)
        }
    }

    func setValues(notification: UserNotification) {
        self.notification = notification
        setBackgroundColor()
        setPostImage()

        avatarImage.image = UIImage()
        if let image = notification.userInfo?.getAvatarImage(), image != UIImage() {
            avatarImage.image = image
        } else if let avatarURL = notification.userInfo?.avatarURL, avatarURL != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFit)
            avatarImage.sd_setImage(with: URL(string: avatarURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }

        username.text = notification.userInfo?.username ?? ""
        setDetailLabel()
    }

    private func setDetailLabel() {
        // timestamp constraints set later because they rely on detail constraints
        let notiType = notification.type
        switch notiType {
        case "like":
            subtitle = "liked your spot"
        case "comment":
            subtitle = "commented on your spot"
        case "friendRequest":
            subtitle = "you are now friends!"
        case "commentTag":
            subtitle = "mentioned you in a comment"
        case "commentLike":
            subtitle = "liked your comment"
        case "commentComment":
            var notiText = "commented on "
            notiText += notification.originalPoster ?? ""
            notiText += "'s spot"
            subtitle = notiText
        case "commentOnAdd":
            var notiText = "commented on "
            notiText += notification.originalPoster ?? ""
            notiText += "'s spot"
            subtitle = notiText
        case "likeOnAdd":
            var notiText = "liked "
            notiText += notification.originalPoster ?? ""
            notiText += "'s spot"
            subtitle = notiText
        case "mapInvite":
            subtitle = "invited you to \(notification.mapName ?? "a map")!"
        case "mapPost":
            var notiText = "spotted to "
            notiText += notification.postInfo?.mapName ?? ""
            subtitle = notiText
        case "post":
            var notiText = "spotted at "
            notiText += notification.postInfo?.spotName ?? ""
            subtitle = notiText
        case "postAdd":
            subtitle = "added you to a spot"
        case "postTag":
            subtitle = "tagged you in a spot!"
        case "publicSpotAccepted":
            subtitle = "Your public submission was approved!"
        case "cityPost":
            var notiText = "posted in "
            notiText += notification.postInfo?.spotName ?? ""
            subtitle = notiText
        case "mapJoin":
            subtitle = "joined \(notification.mapName ?? "a map")"
        case "mapFollow":
            subtitle = "followed \(notification.mapName ?? "a map")"

        default:
            subtitle = notification.type
        }

        time = notification.timestamp.toString(allowDate: false)
        let combined = subtitle + "  " + time
        let attributedString = NSMutableAttributedString(string: combined)
        let detailRange = NSRange(location: 0, length: attributedString.length - time.count)
        let timeRange = NSRange(location: attributedString.length - time.count, length: time.count)

        attributedString.addAttribute(.font, value: UIFont(name: "SFCompactText-Regular", size: 14.5) as Any, range: detailRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1), range: detailRange)

        attributedString.addAttribute(.font, value: UIFont(name: "SFCompactText-Regular", size: 14.5) as Any, range: timeRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor(red: 0.696, green: 0.696, blue: 0.696, alpha: 1), range: timeRange)

        detailLabel.attributedText = attributedString
        detailLabel.sizeToFit()

        detailOriginalHeight = detailLabel.intrinsicContentSize.height
        username.snp.updateConstraints {
            $0.centerY.equalToSuperview().offset((-detailOriginalHeight) / 2)
        }

    }

    private func setPostImage() {
        postImage.image = UIImage()
        let notiType = notification.type
        switch notiType {
        case "friendRequest":
            postImage.image = UIImage(named: "AcceptedYourFriendRequest")
        case "mapInvite", "mapJoin", "mapFollow":
            postImage.image = UIImage(named: "AddedToMap")
        default:
            if !(notification.postInfo?.imageURLs.isEmpty ?? true) {
                postImage.layer.cornerRadius = 5
                let transformer = SDImageResizingTransformer(size: CGSize(width: 88, height: 102), scaleMode: .aspectFill)
                postImage.sd_setImage(
                    with: URL(string: notification.postInfo?.imageURLs.first ?? ""),
                    placeholderImage: nil,
                    options: .highPriority,
                    context: [.imageTransformer: transformer])
            }
        }

        postImage.snp.removeConstraints()
        postImage.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            switch notiType {
            case "friendRequest":
                $0.width.equalTo(33)
                $0.height.equalTo(27)
                $0.trailing.equalToSuperview().offset(-22)
            case "mapInvite", "mapJoin", "mapFollow":
                $0.width.equalTo(45.07)
                $0.height.equalTo(30.04)
                $0.trailing.equalToSuperview().offset(-15)
            default:
                $0.width.equalTo(44)
                $0.height.equalTo(52)
                $0.trailing.equalToSuperview().offset(-14)
            }
        }
    }

    private func setBackgroundColor() {
        if (notification.type == "friendRequest" && notification.status == "accepted" && notification.seen == false) || notification.type == "mapInvite" && notification.seen == false {
            self.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 0.2)
        } else {
            self.backgroundColor = UIColor(named: "SpotBlack")
        }
    }

    func lines(label: UILabel) -> Int {
        let textSize = CGSize(width: label.frame.size.width, height: CGFloat(Float.infinity))
        let rHeight = lroundf(Float(label.sizeThatFits(textSize).height))
        let charSize = lroundf(Float(label.font.lineHeight))
        let lineCount = rHeight / charSize
        return lineCount
    }

    @objc func profileTap() {
        Mixpanel.mainInstance().track(event: "ActivityCellFriendTap")
        notificationControllerDelegate?.getProfile(userProfile: notification.userInfo ?? UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: ""))
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        postImage.sd_cancelCurrentImageLoad()
        avatarImage.sd_cancelCurrentImageLoad()
    }
}
