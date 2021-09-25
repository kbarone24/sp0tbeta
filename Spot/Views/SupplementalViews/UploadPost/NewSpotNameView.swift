//
//  ConfirmSpotView.swift
//  Spot
//
//  Created by Kenny Barone on 8/20/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol NewSpotNameDelegate {
    func finishPassingName(name: String)
}

class NewSpotNameView: UIView {
    
    var textField: UITextField!
    var confirmButton: UIButton!
    var shadowButton: UIButton!
    var delegate: NewSpotNameDelegate?
    
    override init(frame: CGRect) {

        super.init(frame: frame)
        
        backgroundColor = nil
        
        textField = PaddedTextField(frame: CGRect(x: 0, y: 0, width: frame.width, height: 45))
        textField.placeholder = "Name your spot"
        textField.tintColor = .white
        textField.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        textField.font = UIFont(name: "SFCamera-Semibold", size: 17.5)
        textField.backgroundColor = UIColor(red: 0.062, green: 0.062, blue: 0.062, alpha: 1)
        textField.layer.cornerRadius = 10
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        addSubview(textField)
        
        confirmButton = UIButton(frame: CGRect(x: frame.width/2 - 51.3, y: textField.frame.maxY + 19, width: 102.7, height: 34))
        confirmButton.setTitle("Confirm", for: .normal)
        confirmButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 18)
        confirmButton.contentHorizontalAlignment = .center
        confirmButton.contentVerticalAlignment = .center
        confirmButton.setTitleColor(UIColor(named: "SpotBlack"), for: .normal)
        confirmButton.backgroundColor = UIColor(named: "SpotGreen")
        confirmButton.layer.cornerRadius = 12
        addSubview(confirmButton)
        
        shadowButton = UIButton(frame: CGRect(x: confirmButton.frame.minX - 15, y: confirmButton.frame.minY - 15, width: confirmButton.frame.width + 30, height: confirmButton.frame.height + 30))
        shadowButton.addTarget(self, action: #selector(confirmTap(_:)), for: .touchUpInside)
        addSubview(shadowButton)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func confirmTap(_ sender: UIButton) {
        delegate?.finishPassingName(name: textField.text ?? "")
    }
}

extension NewSpotNameView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        confirmButton.alpha = textView.text.isEmpty ? 0.4 : 1.0
    }
}
