//
//  ProfileViewController.swift
//  Spot
//
//  Created by Kenny Barone on 6/6/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

class ProfileViewController: UIViewController, UIViewControllerTransitioningDelegate, UINavigationControllerDelegate {
    
    private let transitionAnimation = BottomToTopTransition()
    
    // function for adding profileViewController
    @objc func addView(_ sender: UIButton){
        let newVC = ProfileViewController()
        navigationController?.pushViewController(newVC, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        modalPresentationStyle = .custom
        navigationController?.delegate = self
        
        let myButton = UIButton(type: .system)///dummy button for adding profile view
        myButton.frame = CGRect(x: 20, y: 130, width: 100, height: 50)
        myButton.setTitle("AddView", for: .normal)
        myButton.addTarget(self, action: #selector(addView(_:)), for: .touchUpInside)
        view.addSubview(myButton)
        self.view = view
    }
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transitionAnimation.transitionMode = operation == .push ? .present:.pop
        return transitionAnimation
    }
    
    override func viewWillAppear(_ animated: Bool){
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool){
        super.viewWillDisappear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool){
        super.viewDidDisappear(animated)
    }
}
