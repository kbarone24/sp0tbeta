//
//  ProfileViewController.swift
//  Spot
//
//  Created by Kenny Barone on 6/6/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit
import Firebase
import Mixpanel
import SDWebImage
import FirebaseFunctions


class ProfileViewController: UIViewController {
        
    // If start from middle position and need to be draggable
    private var fromMiddleDrag: Bool = false
    private var topYContentOffset: CGFloat?
    private var middleYContentOffset: CGFloat?
    
    private var profileCollectionView: UICollectionView!
    private var noPostLabel: UILabel!
    
    // MARK: Fetched datas
    public var userProfile: UserProfile? {
        didSet {
            if profileCollectionView != nil { DispatchQueue.main.async { self.profileCollectionView.reloadData() } }
        }
    }
    public var maps = [CustomMap]() {
        didSet {
            noPostLabel.isHidden = (maps.count == 0 && posts.count == 0) ? false : true
        }
    }
    private var posts = [MapPost]() {
        didSet {
            noPostLabel.isHidden = (maps.count == 0 && posts.count == 0) ? false : true
        }
    }
    private var postImages = [UIImage]() {
        didSet {
            if postImages.count == posts.count {
                DispatchQueue.main.async { self.profileCollectionView.reloadItems(at: [IndexPath(row: 0, section: 1)]) }
            }
        }
    }
    private var relation: ProfileRelation = .myself
    private var pendingFriendRequestNotiID: String? {
        didSet {
            DispatchQueue.main.async { self.profileCollectionView.reloadItems(at: [IndexPath(row: 0, section: 0)]) }
        }
    }
    public var mapSelectedIndex: Int?
    
    private lazy var imageManager = SDWebImageManager()
    public unowned var containerDrawerView: DrawerView?
    
    deinit {
        print("ProfileViewController(\(self) deinit")
        NotificationCenter.default.removeObserver(self)
    }
    
    init(userProfile: UserProfile? = nil, presentedDrawerView: DrawerView? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.userProfile = userProfile == nil ? UserDataModel.shared.userInfo : userProfile
        containerDrawerView = presentedDrawerView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if userProfile!.id ?? "" == "" { getUserInfo(); return }
        getUserRelation()
        viewSetup()
        runFetches()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ProfileOpen")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: true)
        configureDrawerView()
        setUpNavBar()
    }
    
    @objc func mapLikersChanged(_ notification: NSNotification) {
        if let likers = notification.userInfo?["mapLikers"] as? [String] {
            guard mapSelectedIndex != nil else { return }
            maps[mapSelectedIndex!].likers = likers
            mapSelectedIndex = nil
        }
    }

    @objc func editButtonAction() {
        let editVC = EditProfileViewController(userProfile: UserDataModel.shared.userInfo)
        editVC.profileVC = self
        editVC.modalPresentationStyle = .fullScreen
        present(editVC, animated: true)
    }
    
    @objc func friendListButtonAction() {
        Mixpanel.mainInstance().track(event: "FriendListButtonAction")
        let friendListVC = FriendsListController(fromVC: self, allowsSelection: false, showsSearchBar: false, friendIDs: userProfile!.friendIDs, friendsList: userProfile!.friendsList, confirmedIDs: [], presentedWithDrawerView: containerDrawerView!)
        present(friendListVC, animated: true)
    }
    
    @objc func popVC() {
        containerDrawerView?.closeAction()
    }
    
    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        guard let mapDelete = notification.userInfo?["mapDelete"] as? Bool else { return }
        guard let spotDelete = notification.userInfo?["spotDelete"] as? Bool else { return }
        guard let spotRemove = notification.userInfo?["spotRemove"] as? Bool else { return }

        posts.removeAll(where: {$0.id == post.id})
        if mapDelete {
            maps.removeAll(where: {$0.id == post.mapID ?? ""})
            DispatchQueue.main.async { self.profileCollectionView.reloadData() }
            
        } else if post.mapID ?? "" != "" {
            if let i = maps.firstIndex(where: {$0.id == post.mapID!}) {
                maps[i].removePost(postID: post.id!, spotID: spotDelete || spotRemove ? post.spotID! : "")
            }
        }
    }
    
    @objc func notifyMapChange(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        let mapID = userInfo["mapID"] as! String
        let likers = userInfo["mapLikers"] as! [String]
        if let i = maps.firstIndex(where: {$0.id == mapID}) {
            maps[i].likers = likers
            
        }
    }
}

extension ProfileViewController {
    private func setUpNavBar() {
        navigationController!.setNavigationBarHidden(false, animated: true)
        navigationController!.navigationBar.barTintColor = UIColor.white
        navigationController!.navigationBar.isTranslucent = true
        navigationController!.navigationBar.barStyle = .black
        navigationController!.navigationBar.tintColor = UIColor.black
        navigationController!.view.backgroundColor = .white
        
        navigationController!.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1),
            .font: UIFont(name: "SFCompactText-Heavy", size: 20)!
        ]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "BackArrow-1"),
            style: .plain,
            target: self,
            action: #selector(popVC)
        )
    }
    
    private func configureDrawerView() {
        containerDrawerView?.canInteract = false
        containerDrawerView?.swipeDownToDismiss = false
        DispatchQueue.main.async { self.containerDrawerView?.present(to: .Top) }
    }
        
    private func getUserInfo() {
        /// username passed through for tagged user not in friends list
        getUserFromUsername(username: userProfile!.username) { [weak self] user in
            guard let self = self else { return }
            self.userProfile = user
            self.getUserRelation()
            self.viewSetup()
            self.runFetches()
        }
    }
    
    private func getUserRelation() {
        if self.userProfile?.id == UserDataModel.shared.userInfo.id {
            relation = .myself
        } else if UserDataModel.shared.userInfo.friendsList.contains(where: { user in
            user.id == userProfile?.id
        }) {
            relation = .friend
        } else if UserDataModel.shared.userInfo.pendingFriendRequests.contains(where: { user in
            user == userProfile?.id
        }) {
            relation = .pending
        } else if self.userProfile!.pendingFriendRequests.contains(where: { user in
            user == UserDataModel.shared.userInfo.id
        }) {
            relation = .received
        } else {
            relation = .stranger
        }
    }
    
    private func runFetches() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMaps()
            self.getNinePosts()
        }
    }
    
    private func viewSetup() {
        view.backgroundColor = .white
        self.title = ""
        navigationItem.backButtonTitle = ""
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(("DeletePost")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyMapChange(_:)), name: NSNotification.Name(("MapLikersChanged")), object: nil)

        profileCollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
            view.delegate = self
            view.dataSource = self
            view.backgroundColor = .clear
            view.register(ProfileHeaderCell.self, forCellWithReuseIdentifier: "ProfileHeaderCell")
            view.register(ProfileMyMapCell.self, forCellWithReuseIdentifier: "ProfileMyMapCell")
            view.register(ProfileBodyCell.self, forCellWithReuseIdentifier: "ProfileBodyCell")
            return view
        }()
        view.addSubview(profileCollectionView)

        // Setups for if need to drag and start position is middle
        if fromMiddleDrag {
            // Need a new pan gesture to react when profileCollectionView scroll disables
            let scrollViewPanGesture = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
            scrollViewPanGesture.delegate = self
            profileCollectionView.addGestureRecognizer(scrollViewPanGesture)
            profileCollectionView.isScrollEnabled = false
        }
        
        profileCollectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        noPostLabel = UILabel {
            $0.text = "\(userProfile!.name) hasn't posted yet"
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            $0.isHidden = true
            view.addSubview($0)
        }
        noPostLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(243)
        }
    }
    
    private func getNinePosts() {
        let db = Firestore.firestore()
        let query = db.collection("posts").whereField("posterID", isEqualTo: userProfile!.id!).order(by: "timestamp", descending: true).limit(to: 9)
        query.getDocuments { (snap, err) in
            if err != nil  { return }
            self.posts.removeAll()
            self.postImages.removeAll()
            
            // Set transform size
            var size = CGSize(width: 150, height: 150)
            if snap!.documents.count >= 9 {
                size = CGSize(width: 100, height: 100)
            } else if snap!.documents.count >= 4 {
                size = CGSize(width: 150, height: 150)
            } else {
                size = CGSize(width: 200, height: 200)
            }
            
            for doc in snap!.documents {
                do {
                    let unwrappedInfo = try doc.data(as: MapPost.self)
                    guard var postInfo = unwrappedInfo else { return }
                    postInfo = self.setSecondaryPostValues(post: postInfo)
                    self.setPostDetails(post: postInfo) { post in
                        self.posts.append(post)
                        let transformer = SDImageResizingTransformer(size: size, scaleMode: .aspectFill)
                        self.imageManager.loadImage(with: URL(string: postInfo.imageURLs[0]), options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
                            guard self != nil else { return }
                            let image = image ?? UIImage()
                        self?.postImages.append(image)
                        }
                    }
                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                }
            }
        }
    }
    
    private func getMaps() {
        if relation == .myself {
            maps = UserDataModel.shared.userInfo.mapsList
            sortAndReloadMaps()
            return
        }
        
        let db = Firestore.firestore()
        let query = db.collection("maps").whereField("memberIDs", arrayContains: userProfile?.id ?? "")
        query.getDocuments { (snap, err) in
            if err != nil  { return }
            self.maps.removeAll()
            for doc in snap!.documents {
                do {
                    let unwrappedInfo = try doc.data(as: CustomMap.self)
                    guard let mapInfo = unwrappedInfo else { return }
                    /// friend doesn't have access to secret map
                    if mapInfo.secret && !mapInfo.memberIDs.contains(UserDataModel.shared.uid) { continue }
                    self.maps.append(mapInfo)
                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                }
            }
            self.sortAndReloadMaps()
        }
    }
    
    private func sortAndReloadMaps() {
        maps.sort(by: {$0.userTimestamp.seconds > $1.userTimestamp.seconds})
        DispatchQueue.main.async { self.profileCollectionView.reloadData() }
    }
    
    private func getMyMap() -> CustomMap {
        var mapData = CustomMap(founderID: "", imageURL: "", likers: [], mapName: "", memberIDs: [], posterIDs: [], posterUsernames: [], postIDs: [], postImageURLs: [], secret: false, spotIDs: [])
        mapData.createPosts(posts: posts)
        return mapData
    }
}

extension ProfileViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : (maps.count + 1)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.section == 0 ? "ProfileHeaderCell" : indexPath.row == 0 ? "ProfileMyMapCell" : "ProfileBodyCell", for: indexPath)
        if let headerCell = cell as? ProfileHeaderCell {
            headerCell.cellSetup(userProfile: userProfile!, relation: relation)
            if relation == .myself {
                headerCell.actionButton.addTarget(self, action: #selector(editButtonAction), for: .touchUpInside)
            }
            headerCell.friendListButton.addTarget(self, action: #selector(friendListButtonAction), for: .touchUpInside)
            return headerCell
        } else if let mapCell = cell as? ProfileMyMapCell {
            mapCell.cellSetup(userAccount: userProfile!.username, myMapsImage: postImages, relation: relation)
            return mapCell
        } else if let bodyCell = cell as? ProfileBodyCell {
            bodyCell.cellSetup(mapData: maps[indexPath.row - 1])
            return bodyCell
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return section == 0 ? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) : UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
    }
        
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (view.frame.width - 40) / 2
        return indexPath.section == 0 ? CGSize(width: view.frame.width, height: 160) : CGSize(width: width , height: 250)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            Mixpanel.mainInstance().track(event: "ProfileMapSelect")
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            } completion: { (Bool) in
                UIView.animate(withDuration: 0.15) {
                    collectionCell?.transform = .identity
                }
            }
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.row == 0 ? "ProfileMyMapCell" : "ProfileBodyCell", for: indexPath)
            if let _ = cell as? ProfileMyMapCell {
                let mapData = getMyMap()
                let customMapVC = CustomMapController(userProfile: userProfile, mapData: mapData, postsList: [], presentedDrawerView: containerDrawerView, mapType: .myMap)
                navigationController?.pushViewController(customMapVC, animated: true)
            } else if let _ = cell as? ProfileBodyCell {
                mapSelectedIndex = indexPath.row - 1
                let customMapVC = CustomMapController(userProfile: userProfile, mapData: maps[mapSelectedIndex!], postsList: [], presentedDrawerView: containerDrawerView, mapType: .customMap)
                navigationController?.pushViewController(customMapVC, animated: true)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = .identity
            }
        }
    }
}

extension ProfileViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Show navigation bar when user scroll pass the header section
        if topYContentOffset != nil {
            if scrollView.contentOffset.y > -91.0 {
                navigationController?.navigationBar.isTranslucent = false
                if(scrollView.contentOffset.y > 0){
                    self.title = userProfile?.name
                } else { self.title = ""}
            }
        } else {
            if fromMiddleDrag == false {
                topYContentOffset = scrollView.contentOffset.y
            }
        }

        if fromMiddleDrag {
            // Disable the bouncing effect when scroll view is scrolled to top
            if topYContentOffset != nil {
                if
                    containerDrawerView?.status == .Top &&
                    scrollView.contentOffset.y <= topYContentOffset!
                {
                    scrollView.contentOffset.y = topYContentOffset!
                }
            }
            
            // Get middle y content offset
            if middleYContentOffset == nil {
                middleYContentOffset = scrollView.contentOffset.y
            }
            
            // Set scroll view content offset when in transition
            if
                middleYContentOffset != nil &&
                topYContentOffset != nil &&
                scrollView.contentOffset.y <= middleYContentOffset! &&
                containerDrawerView!.slideView.frame.minY >= middleYContentOffset! - topYContentOffset!
            {
                scrollView.contentOffset.y = middleYContentOffset!
            }
            
            // Whenever drawer view is not in top position, scroll to top, disable scroll and enable drawer view swipe to next state
            if containerDrawerView?.status != .Top {
                profileCollectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
                profileCollectionView.isScrollEnabled = false
                containerDrawerView?.swipeToNextState = true
            }
        }
    }
}

extension ProfileViewController: UIGestureRecognizerDelegate {
    @objc func onPan(_ recognizer: UIPanGestureRecognizer) {
        // Swipe up y translation < 0
        // Swipe down y translation > 0
        let yTranslation = recognizer.translation(in: recognizer.view).y
        
        // Get the initial Top y position contentOffset
        if containerDrawerView?.status == .Top && topYContentOffset == nil {
            topYContentOffset = profileCollectionView.contentOffset.y
        }
        
        // Enter full screen then enable collection view scrolling and determine if need drawer view swipe to next state feature according to user swipe direction
        if
            topYContentOffset != nil &&
            containerDrawerView?.status == .Top &&
            profileCollectionView.contentOffset.y <= topYContentOffset!
        {
            profileCollectionView.isScrollEnabled = true
            containerDrawerView?.swipeToNextState = yTranslation > 0 ? true : false
        }

        // Preventing the drawer view to be dragged when it's status is top and user is scrolling down
        if
            containerDrawerView?.status == .Top &&
            profileCollectionView.contentOffset.y > topYContentOffset ?? -50 &&
            yTranslation > 0 &&
            containerDrawerView?.swipeToNextState == false
        {
            containerDrawerView?.canDrag = false
            containerDrawerView?.slideView.frame.origin.y = 0
        }
        
        // Enable drag when the drawer view is on top and user swipes down
        if profileCollectionView.contentOffset.y <= topYContentOffset ?? -50 && yTranslation >= 0 {
            containerDrawerView?.canDrag = true
        }
        
        // Need to prevent content in collection view being scrolled when the status of drawer view is top but frame.minY is not 0
        
        recognizer.setTranslation(.zero, in: recognizer.view)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
