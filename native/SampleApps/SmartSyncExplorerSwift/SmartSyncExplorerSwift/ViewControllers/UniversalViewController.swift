//
//  UniversalViewController.swift
//  SmartSyncExplorerSwift
//
//  Created by Nicholas McDonald on 1/22/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

import UIKit

class UniversalViewController: UIViewController {

    var commonConstraints: [NSLayoutConstraint] = []
    var compactConstraints: [NSLayoutConstraint] = []
    var regularConstraints: [NSLayoutConstraint] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.navigationBar.barTintColor = UIColor.appDarkBlue
        self.navigationController?.navigationBar.isTranslucent = false
        UIApplication.shared.statusBarStyle = .lightContent
        
        guard let font = UIFont.appRegularFont(20) else { return }
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white, NSAttributedStringKey.font: font]
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if self.commonConstraints.count > 0 && self.commonConstraints[0].isActive == false{
            self.view.addConstraints(self.commonConstraints)
        }
        
        if self.traitCollection.verticalSizeClass == .regular && self.traitCollection.horizontalSizeClass == .regular {
            if self.compactConstraints.count > 0 && self.compactConstraints[0].isActive {
                self.view.removeConstraints(self.compactConstraints)
            }
            self.view.addConstraints(self.regularConstraints)
        } else {
            if self.regularConstraints.count > 0 && self.regularConstraints[0].isActive {
                self.view.removeConstraints(self.regularConstraints)
            }
            self.view.addConstraints(self.compactConstraints)
        }
    }
}
