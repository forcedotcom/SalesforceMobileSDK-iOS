//
//  IDPLoginNavViewController.swift
//  RestAPIExplorerSwift
//
//  Created by Nicholas McDonald on 1/15/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

import UIKit
import SalesforceSDKCore.SFSDKLoginFlowSelectionView

class IDPLoginNavViewController: UINavigationController, SFSDKLoginFlowSelectionView {
    weak var selectionFlowDelegate:SFSDKLoginFlowSelectionViewDelegate?
    var appOptions:[AnyHashable: Any]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let controller = IDPLoginViewController(nibName: nil, bundle: nil)
        controller.loginSelectionDelegate = self
        self.pushViewController(controller, animated: true)
    }
}

extension IDPLoginNavViewController: IDPLoginViewControllerDelegate {
    func loginUsingIDP() {
        if let d = self.selectionFlowDelegate {
            d.loginFlowSelectionIDPSelected(self, options: self.appOptions)
        }
    }
    
    func loginUsingApp() {
        if let d = self.selectionFlowDelegate {
            d.loginFlowSelectionLocalLoginSelected(self, options: self.appOptions)
        }
    }
}
