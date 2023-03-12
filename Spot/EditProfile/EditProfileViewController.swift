//
//  EditProfileViewController.swift
//  Spot
//
//  Created by Arnold on 7/8/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFunctions
import Mixpanel
import UIKit

protocol EditProfileDelegate: AnyObject {
    func finishPassing(userInfo: UserProfile)
}

class EditProfileViewController: UIViewController {
    var profileImage: UIImageView = {
        let view = UIImageView()
        view.layer.cornerRadius = 51.5
        view.layer.masksToBounds = true
        view.isUserInteractionEnabled = true
        return view
    }()
    private var profilePicSelectionButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "EditProfilePicture"), for: .normal)
        button.setTitle("", for: .normal)
        return button
    }()
    private var avatarLabel: UILabel = {
        let label = UILabel()
        label.text = "Avatar"
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        return label
    }()
    var avatarImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        return view
    }()
    private var avatarEditButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "EditAvatar"), for: .normal)
        button.setTitle("", for: .normal)
        return button
    }()
    private var locationLabel: UILabel = {
        let label = UILabel()
        label.text = "Location"
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        return label
    }()
    var locationTextfield: UITextField = {
        let textField = UITextField()
        textField.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        textField.layer.cornerRadius = 11
        textField.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        textField.textColor = .white
        textField.tintColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
        textField.setLeftPaddingPoints(8)
        textField.setRightPaddingPoints(8)
        return textField
    }()
    private var accountOptionsButton: UIButton = {
        let button = UIButton()
        button.setTitle("Account options", for: .normal)
        button.setTitleColor(UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 17.5)
        return button
    }()
    lazy var activityIndicator = CustomActivityIndicator()

    var profileChanged: Bool = false
    var avatarChanged: Bool = false

    var delegate: EditProfileDelegate?
    var userProfile: UserProfile?
    let db = Firestore.firestore()

    init(userProfile: UserProfile? = nil) {
        self.userProfile = userProfile == nil ? UserDataModel.shared.userInfo : userProfile
        super.init(nibName: nil, bundle: nil)
        edgesForExtendedLayout = []
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
    }

    private func setUpNavBar() {
        navigationController?.setUpDarkNav(translucent: true)
        navigationItem.title = "Edit Profile"

        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTap))
        cancelButton.tintColor = .lightGray
        navigationItem.leftBarButtonItem = cancelButton

        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneTap))
        doneButton.tintColor = UIColor(named: "SpotGreen")
        navigationItem.rightBarButtonItem = doneButton
    }

    private func viewSetup() {
        view.backgroundColor = UIColor(named: "SpotBlack")
        let profilePicTap = UITapGestureRecognizer(target: self, action: #selector(profilePicSelectionAction))
        profileImage.addGestureRecognizer(profilePicTap)
        view.addSubview(profileImage)
        profileImage.snp.makeConstraints {
            $0.width.height.equalTo(103)
            $0.top.equalTo(28)
            $0.centerX.equalToSuperview()
        }
        profileImage.sd_setImage(with: URL(string: userProfile?.imageURL ?? ""))

        profilePicSelectionButton.addTarget(self, action: #selector(profilePicSelectionAction), for: .touchUpInside)
        view.addSubview(profilePicSelectionButton)
        profilePicSelectionButton.snp.makeConstraints {
            $0.width.height.equalTo(42)
            $0.trailing.equalTo(profileImage).offset(5)
            $0.bottom.equalTo(profileImage).offset(3)
        }

        view.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints {
            $0.top.equalTo(profileImage.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        view.addSubview(avatarImage)
        let avatarTap = UITapGestureRecognizer(target: self, action: #selector(avatarEditAction))
        avatarImage.addGestureRecognizer(avatarTap)
        avatarImage.sd_setImage(with: URL(string: userProfile?.avatarURL ?? ""))
        avatarImage.snp.makeConstraints {
            $0.top.equalTo(avatarLabel.snp.bottom).offset(2)
            $0.leading.equalToSuperview().offset(16)
            $0.width.equalTo(40.5)
            $0.height.equalTo(36)
        }

        avatarEditButton.addTarget(self, action: #selector(avatarEditAction), for: .touchUpInside)
        view.addSubview(avatarEditButton)
        avatarEditButton.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(1)
            $0.centerY.equalTo(avatarImage)
            $0.width.height.equalTo(22)
        }

        view.addSubview(locationLabel)
        locationLabel.snp.makeConstraints {
            $0.top.equalTo(avatarImage.snp.bottom).offset(18)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        locationTextfield.delegate = self
        locationTextfield.text = userProfile?.currentLocation ?? ""
        view.addSubview(locationTextfield)
        locationTextfield.snp.makeConstraints {
            $0.top.equalTo(locationLabel.snp.bottom).offset(1)
            $0.leading.equalToSuperview().offset(14)
            $0.trailing.equalToSuperview().inset(63)
            $0.height.equalTo(36)
        }

        accountOptionsButton.addTarget(self, action: #selector(addActionSheet), for: .touchUpInside)
        view.addSubview(accountOptionsButton)
        accountOptionsButton.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(72)
            $0.centerX.equalToSuperview()
        }

        activityIndicator.isHidden = true
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(150)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(30)
        }
    }
}

extension EditProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let image = info[.editedImage] as? UIImage else { return }
        profileImage.image = image
        profileChanged = true
        dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
}

extension EditProfileViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count <= 25
    }
}
