/*
 RootViewController.swift
 RestAPIExplorerSwift
 
 Created by Nicholas McDonald on 1/8/18.
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import UIKit
import SalesforceSDKCore
import LocalAuthentication

struct ContentSection {
    var title: String {
        didSet {
            self.titleLabel.text = title
        }
    }
    var attributedTitle: NSAttributedString? {
        didSet {
            self.titleLabel.attributedText = attributedTitle
        }
    }
    var contentView = UIView()
    var container = UIView()
    private let titleLabel = UILabel()

    static let horizontalSpace: CGFloat = 18.0
    static let interItemVerticalSpace: CGFloat = 4.0
    static let topSpace: CGFloat = 8.0
    static let bottomSpace: CGFloat = 12.0
    static let horizontalMargin: CGFloat = 20.0
    static let verticalMargin: CGFloat = 16.0
    static let titleMargin: CGFloat = 8.0

    init(_ title: String) {
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.container.translatesAutoresizingMaskIntoConstraints = false

        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel.font = UIFont.appRegularFont(20)
        self.titleLabel.text = title
        self.titleLabel.textColor = UIColor.sfsdk_color(forLightStyle: .appDarkBlue, darkStyle: .white)
        self.container.addSubview(self.titleLabel)
        self.titleLabel.leftAnchor.constraint(equalTo: self.container.leftAnchor, constant: ContentSection.horizontalMargin).isActive = true
 
        self.titleLabel.rightAnchor.constraint(equalTo: self.container.rightAnchor, constant: -ContentSection.horizontalMargin).isActive = true
        self.titleLabel.topAnchor.constraint(equalTo: self.container.topAnchor, constant: ContentSection.titleMargin).isActive = true
        
        self.container.addSubview(self.contentView)
        self.contentView.leftAnchor.constraint(equalTo: self.container.leftAnchor, constant: ContentSection.horizontalMargin).isActive = true
        self.contentView.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor).isActive = true
        self.contentView.rightAnchor.constraint(equalTo: self.container.rightAnchor, constant: -ContentSection.horizontalMargin).isActive = true
        self.contentView.bottomAnchor.constraint(equalTo: self.container.bottomAnchor, constant: -ContentSection.verticalMargin).isActive = true
        
        self.title = title
    }
}

class RootViewController: UIViewController {
    weak var presentedActions: ActionTableViewController?
    weak var logoutAlert: UIAlertController?
    
    fileprivate let paramSection = ContentSection("Parameters for action based query")
    fileprivate let querySection = ContentSection("Manual query")
    fileprivate var responseSection = ContentSection("Response for...")
    
    fileprivate var textFields: [UITextField] = []
    fileprivate var textViews: [UITextView] = []
    fileprivate var objectTypeTextField: UITextField!
    fileprivate var objectIdTextField: UITextField!
    fileprivate var externalIdTextField: UITextField!
    fileprivate var searchTextField: UITextField!
    fileprivate var queryTextField: UITextField!
    fileprivate var externalFieldIdTextField: UITextField!
    fileprivate var fieldListTextField: UITextField!
    fileprivate var fieldsTextView: UITextView!
    fileprivate var objectListTextField: UITextField!
    fileprivate var userIdTextField: UITextField!
    fileprivate var pageTextField: UITextField!
    fileprivate var versionTextField: UITextField!
    fileprivate var objectIdListTextField: UITextField!
    fileprivate var entityIdTextField: UITextField!
    fileprivate var shareTypeTextField: UITextField!
    fileprivate var manualQueryTextField: UITextField!
    fileprivate var paramsTextView: UITextView!
    fileprivate var methodControl: UISegmentedControl!
    fileprivate var responseForLabel: UILabel!
    fileprivate var responseForTextView: UITextView!
    
    fileprivate var responseContractedTopConstraint: NSLayoutConstraint!
    fileprivate var responseExpandedTopConstraint: NSLayoutConstraint!
    
    fileprivate var fullName: String {
        if let currentAccount = UserAccountManager.shared.currentUserAccount {
            return (currentAccount.idData.firstName ?? "") + " " + (currentAccount.idData.lastName)
        }
        return ""
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.appContentBackground

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(clearPopoversForPasscode),
                                               name: NSNotification.Name(rawValue: kSFScreenLockFlowWillBegin),
                                               object: nil)
        
        guard let font = UIFont.appRegularFont(20) else {
            return
        }
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.backgroundColor = UIColor.appDarkBlue
        navBarAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white, NSAttributedString.Key.font: font]

        self.navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance;
        self.navigationController?.navigationBar.compactAppearance = navBarAppearance;
        self.navigationController?.navigationBar.standardAppearance = navBarAppearance;
        self.navigationController?.navigationBar.compactScrollEdgeAppearance = navBarAppearance;
     
        self.title = "RestAPI Explorer"
        
        guard let leftImage = UIImage(named: "list")?.withRenderingMode(.alwaysOriginal), let _ = UIImage(named: "search")?.withRenderingMode(.alwaysOriginal) else {
            return
        }
        let left = UIBarButtonItem(image: leftImage, style: .plain, target: self, action: #selector(didPressLeftNavButton(_:)))
        self.navigationItem.leftBarButtonItem = left
        
        let paramContent = self.buildParametersSection()
        let queryContent = self.buildQuerySection()
        let responseContent = self.buildResponseSection()
        self.updateBorderColor()
        
        let parambar = UIView()
        parambar.translatesAutoresizingMaskIntoConstraints = false
        parambar.backgroundColor = UIColor.appViewBorder
        
        let querybar = UIView()
        querybar.translatesAutoresizingMaskIntoConstraints = false
        querybar.backgroundColor = UIColor.appViewBorder
        
        self.view.addSubview(paramContent)
        self.view.addSubview(parambar)
        self.view.addSubview(queryContent)
        self.view.addSubview(querybar)
        self.view.addSubview(responseContent)
        
        let topAnchor = self.view.safeAreaLayoutGuide.topAnchor
        let bottomAnchor = self.view.safeAreaLayoutGuide.bottomAnchor
        let rightAnchor = self.view.safeAreaLayoutGuide.rightAnchor
        let leftAnchor = self.view.safeAreaLayoutGuide.leftAnchor
        
        // let safe = self.view.safeAreaLayoutGuide
        paramContent.topAnchor.constraint(equalTo: topAnchor).isActive = true
        paramContent.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        paramContent.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        
        parambar.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        parambar.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        parambar.topAnchor.constraint(equalTo: paramContent.bottomAnchor).isActive = true
        parambar.heightAnchor.constraint(equalToConstant: 1.0).isActive = true
        
        queryContent.topAnchor.constraint(equalTo: parambar.bottomAnchor).isActive = true
        queryContent.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        queryContent.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        
        querybar.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        querybar.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        querybar.topAnchor.constraint(equalTo: queryContent.bottomAnchor).isActive = true
        querybar.heightAnchor.constraint(equalToConstant: 1.0).isActive = true
        
        self.responseContractedTopConstraint = responseContent.topAnchor.constraint(equalTo: querybar.bottomAnchor)
        self.responseExpandedTopConstraint = responseContent.topAnchor.constraint(equalTo: topAnchor)
        self.responseContractedTopConstraint.isActive = true
        responseContent.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        responseContent.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        responseContent.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        self.view.layoutIfNeeded()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func didPressLeftNavButton(_ sender: UIBarButtonItem) {
        let actions = ActionTableViewController()
        actions.delegate = self
        self.presentedActions = actions
        
        actions.modalPresentationStyle = UIModalPresentationStyle.popover
        actions.preferredContentSize = CGSize(width: 480.0, height: 600.0)
        
        let presentationController = actions.popoverPresentationController
        presentationController?.barButtonItem = sender
        self.present(actions, animated: true, completion: nil)
    }
    
    func textFieldWithTitle(_ title:String) -> (UIView, UITextField) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = UIFont.appRegularFont(12)
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.textColor = UIColor.appLabel
        
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = UIFont.appBoldFont(14)
        field.textColor = UIColor.appTextField
        field.autocorrectionType = .no
        field.borderStyle = .none
        field.layer.cornerRadius = 4.0
        field.layer.borderWidth = 1.0
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 4, height: 4))
        field.leftViewMode = .always
        field.backgroundColor = UIColor.appSecondarySystemGroupedBackground
        
        container.addSubview(label)
        container.addSubview(field)
        
        label.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        label.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        label.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
        field.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        field.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        field.topAnchor.constraint(equalTo: label.bottomAnchor, constant:2.0).isActive = true
        field.heightAnchor.constraint(equalToConstant: 32.0).isActive = true
        field.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        
        self.textFields.append(field)
        return (container, field)
    }
    
    func textViewWithTitle(_ title:String) -> (UIView, UITextView) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = UIFont.appRegularFont(12)
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.textColor = UIColor.sfsdk_color(forLightStyle: UIColor.appLabel, darkStyle: UIColor.white)
        
        let field = UITextView()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = UIFont.appBoldFont(14)
        field.textColor = UIColor.appTextField
        field.backgroundColor = UIColor.appSecondarySystemGroupedBackground
        field.layer.cornerRadius = 4.0
        field.layer.borderWidth = 1.0
        
        container.addSubview(label)
        container.addSubview(field)
        
        label.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        label.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        label.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
        field.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        field.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        field.topAnchor.constraint(equalTo: label.bottomAnchor, constant:2.0).isActive = true
        field.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        self.textViews.append(field)
        return (container, field)
    }
    
    func buildParametersSection() -> UIView {
        let objType = self.textFieldWithTitle("Object Type")
        let objId = self.textFieldWithTitle("Object ID")
        let extId = self.textFieldWithTitle("External ID")
        let search = self.textFieldWithTitle("Search")
        let query = self.textFieldWithTitle("Query")
        let extFieldId = self.textFieldWithTitle("External Field ID")
        let fieldList = self.textFieldWithTitle("Field List")
        let fields = self.textViewWithTitle("Fields")
        let objList = self.textFieldWithTitle("Object List")
        let userId = self.textFieldWithTitle("User ID")
        let page = self.textFieldWithTitle("Page")
        let version = self.textFieldWithTitle("Version")
        let objIdList = self.textFieldWithTitle("Object ID List")
        let entityId = self.textFieldWithTitle("Entity ID")
        let shareType = self.textFieldWithTitle("Share Type")
        
        self.paramSection.container.backgroundColor = UIColor.appGroupedBackground
        let content = self.paramSection.contentView
        
        content.addSubview(objType.0)
        content.addSubview(objId.0)
        content.addSubview(extId.0)
        
        content.addSubview(search.0)
        content.addSubview(query.0)
        content.addSubview(extFieldId.0)
        
        content.addSubview(fieldList.0)
        content.addSubview(fields.0)
        content.addSubview(objList.0)
        
        content.addSubview(userId.0)
        content.addSubview(page.0)
        content.addSubview(version.0)
        
        content.addSubview(objIdList.0)
        content.addSubview(entityId.0)
        content.addSubview(shareType.0)
        
        // top row
        objType.0.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
        objType.0.topAnchor.constraint(equalTo: content.topAnchor, constant: ContentSection.topSpace).isActive = true
        objId.0.leftAnchor.constraint(equalTo: objType.0.rightAnchor, constant: ContentSection.horizontalSpace).isActive = true
        objId.0.topAnchor.constraint(equalTo: objType.0.topAnchor).isActive = true
        extId.0.leftAnchor.constraint(equalTo: objId.0.rightAnchor, constant: ContentSection.horizontalSpace).isActive = true
        extId.0.topAnchor.constraint(equalTo: objType.0.topAnchor).isActive = true
        extId.0.rightAnchor.constraint(equalTo: content.rightAnchor).isActive = true
        objId.0.widthAnchor.constraint(equalTo: objType.0.widthAnchor).isActive = true
        extId.0.widthAnchor.constraint(equalTo: objType.0.widthAnchor).isActive = true
        objId.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        extId.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        
        // second row
        search.0.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
        search.0.topAnchor.constraint(equalTo: objType.0.bottomAnchor, constant: ContentSection.interItemVerticalSpace).isActive = true
        query.0.leftAnchor.constraint(equalTo: search.0.rightAnchor, constant: ContentSection.horizontalSpace).isActive = true
        query.0.topAnchor.constraint(equalTo: search.0.topAnchor).isActive = true
        extFieldId.0.leftAnchor.constraint(equalTo: query.0.rightAnchor, constant: ContentSection.horizontalSpace).isActive = true
        extFieldId.0.topAnchor.constraint(equalTo: search.0.topAnchor).isActive = true
        extFieldId.0.rightAnchor.constraint(equalTo: content.rightAnchor).isActive = true
        query.0.widthAnchor.constraint(equalTo: search.0.widthAnchor).isActive = true
        extFieldId.0.widthAnchor.constraint(equalTo: search.0.widthAnchor).isActive = true
        search.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        query.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        extFieldId.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        
        // third and fourth row
        fieldList.0.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
        fieldList.0.topAnchor.constraint(equalTo: search.0.bottomAnchor, constant: ContentSection.interItemVerticalSpace).isActive = true
        fields.0.leftAnchor.constraint(equalTo: fieldList.0.rightAnchor, constant: ContentSection.horizontalSpace).isActive = true
        fields.0.topAnchor.constraint(equalTo: fieldList.0.topAnchor).isActive = true
        fields.0.rightAnchor.constraint(equalTo: content.rightAnchor).isActive = true
        fields.0.bottomAnchor.constraint(equalTo: objList.0.bottomAnchor).isActive = true
        objList.0.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
        objList.0.topAnchor.constraint(equalTo: fieldList.0.bottomAnchor, constant: ContentSection.interItemVerticalSpace).isActive = true
        fieldList.0.widthAnchor.constraint(equalTo: search.0.widthAnchor).isActive = true
        objList.0.widthAnchor.constraint(equalTo: search.0.widthAnchor).isActive = true
        fieldList.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        objList.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        
        // sixth row
        userId.0.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
        userId.0.topAnchor.constraint(equalTo: objList.0.bottomAnchor, constant: ContentSection.interItemVerticalSpace).isActive = true
        page.0.leftAnchor.constraint(equalTo: userId.0.rightAnchor, constant: ContentSection.horizontalSpace).isActive = true
        page.0.topAnchor.constraint(equalTo: userId.0.topAnchor).isActive = true
        version.0.leftAnchor.constraint(equalTo: page.0.rightAnchor, constant: ContentSection.horizontalSpace).isActive = true
        version.0.topAnchor.constraint(equalTo: userId.0.topAnchor).isActive = true
        version.0.rightAnchor.constraint(equalTo: content.rightAnchor).isActive = true
        page.0.widthAnchor.constraint(equalTo: search.0.widthAnchor).isActive = true
        version.0.widthAnchor.constraint(equalTo: search.0.widthAnchor).isActive = true
        userId.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        page.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        version.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        
        // seventh row
        objIdList.0.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
        objIdList.0.topAnchor.constraint(equalTo: userId.0.bottomAnchor, constant: ContentSection.interItemVerticalSpace).isActive = true
        objIdList.0.bottomAnchor.constraint(equalTo: content.bottomAnchor).isActive = true
        entityId.0.leftAnchor.constraint(equalTo: objIdList.0.rightAnchor, constant: ContentSection.horizontalSpace).isActive = true
        entityId.0.topAnchor.constraint(equalTo: objIdList.0.topAnchor).isActive = true
        shareType.0.leftAnchor.constraint(equalTo: entityId.0.rightAnchor, constant: ContentSection.horizontalSpace).isActive = true
        shareType.0.topAnchor.constraint(equalTo: objIdList.0.topAnchor).isActive = true
        shareType.0.rightAnchor.constraint(equalTo: content.rightAnchor).isActive = true
        entityId.0.widthAnchor.constraint(equalTo: objIdList.0.widthAnchor).isActive = true
        shareType.0.widthAnchor.constraint(equalTo: objIdList.0.widthAnchor).isActive = true
        objIdList.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        entityId.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        shareType.0.heightAnchor.constraint(equalTo: objType.0.heightAnchor).isActive = true
        
        // preload initial values
        objType.1.text = "Contact"
        search.1.text = "Find {John}"
        query.1.text = "select name from Account"
        fieldList.1.text = "FirstName, OwnerId"
        fields.1.text = "{FirstName:John, LastName:Doe}"
        objList.1.text = "Contact"
        page.1.text = "0"
        version.1.text = "1"
        
        self.objectTypeTextField = objType.1
        self.objectIdTextField = objId.1
        self.externalIdTextField = extId.1
        self.searchTextField = search.1
        self.queryTextField = query.1
        self.externalFieldIdTextField = extFieldId.1
        self.fieldListTextField = fieldList.1
        self.fieldsTextView = fields.1
        self.objectListTextField = objList.1
        self.userIdTextField = userId.1
        self.pageTextField = page.1
        self.versionTextField = version.1
        self.objectIdListTextField = objIdList.1
        self.entityIdTextField = entityId.1
        self.shareTypeTextField = shareType.1
        
        return self.paramSection.container
    }
    
    func buildQuerySection() -> UIView {
        let query = self.textFieldWithTitle("/services/data")
        
        let goButton = UIButton(type: .custom)
        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.setTitle("Go", for: .normal)
        goButton.backgroundColor = UIColor.appButton
        goButton.layer.cornerRadius = 4.0
        goButton.addTarget(self, action: #selector(userDidTapQueryButton(_:)), for: .touchUpInside)
        
        let params = self.textViewWithTitle("params (javascript dictionary")
        
        let methodTitle = UILabel()
        methodTitle.translatesAutoresizingMaskIntoConstraints = false
        methodTitle.text = "method"
        methodTitle.font = UIFont.appRegularFont(12)
        methodTitle.textColor = UIColor.appLabel
        
        let methodControl = UISegmentedControl(items: ["Get", "Post", "Put", "Del", "Head", "Patch"])
        methodControl.translatesAutoresizingMaskIntoConstraints = false
        methodControl.selectedSegmentIndex = 0;
        
        self.querySection.container.backgroundColor = UIColor.appGroupedBackground
        let content = self.querySection.contentView
        
        content.addSubview(query.0)
        content.addSubview(goButton)
        content.addSubview(params.0)
        content.addSubview(methodTitle)
        content.addSubview(methodControl)
        
        query.0.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
        query.0.topAnchor.constraint(equalTo: content.topAnchor, constant:ContentSection.topSpace).isActive = true
        goButton.leftAnchor.constraint(equalTo: query.1.rightAnchor, constant:ContentSection.horizontalSpace).isActive = true
        goButton.topAnchor.constraint(equalTo: query.1.topAnchor).isActive = true
        goButton.bottomAnchor.constraint(equalTo: query.1.bottomAnchor).isActive = true
        goButton.rightAnchor.constraint(equalTo: content.rightAnchor).isActive = true
        goButton.widthAnchor.constraint(equalToConstant: 60.0).isActive = true
        
        params.0.topAnchor.constraint(equalTo: query.0.bottomAnchor, constant:ContentSection.interItemVerticalSpace).isActive = true
        params.0.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
        params.0.rightAnchor.constraint(equalTo: content.rightAnchor).isActive = true
        params.1.heightAnchor.constraint(equalToConstant: 80.0).isActive = true
        
        methodTitle.topAnchor.constraint(equalTo: params.0.bottomAnchor, constant:ContentSection.topSpace).isActive = true
        methodTitle.leftAnchor.constraint(equalTo: params.0.leftAnchor).isActive = true
        
        methodControl.topAnchor.constraint(equalTo: methodTitle.bottomAnchor, constant:ContentSection.interItemVerticalSpace).isActive = true
        methodControl.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
        methodControl.rightAnchor.constraint(equalTo: content.rightAnchor).isActive = true
        methodControl.bottomAnchor.constraint(equalTo: content.bottomAnchor).isActive = true
        
        self.manualQueryTextField = query.1
        self.paramsTextView = params.1
        self.methodControl = methodControl
        
        return self.querySection.container
    }
    
    func buildResponseSection() -> UIView {
        
        self.responseSection.container.backgroundColor = UIColor.appContentBackground
        let content = self.responseSection.contentView
        
        let expandButton = UIButton(type: .custom)
        expandButton.translatesAutoresizingMaskIntoConstraints = false
        expandButton.setImage(UIImage(named: "up"), for: .normal)
        expandButton.addTarget(self, action: #selector(userDidTapExpandButton(_:)), for: .touchUpInside)
        
        self.responseSection.container.addSubview(expandButton)
        
        expandButton.centerXAnchor.constraint(equalTo: self.responseSection.container.centerXAnchor).isActive = true
        expandButton.topAnchor.constraint(equalTo: self.responseSection.container.topAnchor, constant: -10).isActive = true
        expandButton.widthAnchor.constraint(equalToConstant: 100.0).isActive = true
        expandButton.heightAnchor.constraint(equalToConstant: 40.0).isActive = true
        
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = UIFont.appBoldFont(14)
        textView.textColor = UIColor.salesforceLabel
        textView.backgroundColor = UIColor.appTextViewYellowBackground
        textView.layer.borderWidth = 1.0
        textView.layer.cornerRadius = 4.0
        
        content.addSubview(textView)
        
        textView.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
        textView.rightAnchor.constraint(equalTo: content.rightAnchor).isActive = true
        textView.topAnchor.constraint(equalTo: content.topAnchor, constant: ContentSection.topSpace).isActive = true
        textView.bottomAnchor.constraint(equalTo: content.bottomAnchor).isActive = true
        
        self.responseForTextView = textView
        
        return self.responseSection.container
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            self.updateBorderColor()
        }
    }
    
    func updateBorderColor() -> Void {
        for textField in self.textFields {
            textField.layer.borderColor = UIColor.appTextFieldBorder.cgColor
        }
        for textView in self.textViews {
            textView.layer.borderColor = UIColor.appTextFieldBorder.cgColor
        }
    }
    
    @objc func userDidTapQueryButton(_ sender: UIButton) {
        print("handle tapped query button")
        self.view.endEditing(true)
        guard let path = self.manualQueryTextField.text, let method = RestRequest.Method(rawValue: self.methodControl.selectedSegmentIndex) else {return}
        
        var queryParams: [String: Any]?
        if let params = self.paramsTextView.text {
            queryParams = SFJsonUtils.object(fromJSONString: params) as? [String: Any]
        }
        
        let request = RestRequest(method: method, path: path, queryParams: queryParams)
        RestClient.shared.send(request: request) { result in
            switch result {
                case .success(let response):
                    self.handleSuccess(request: request, response: response)
                case .failure(let error):
                    self.handleError(request: request, error: error)
            }
        }
    }
    
    func handleSuccess(request: RestRequest, response: RestResponse) {
        guard let jsonResponse = try? response.asJson() else {
            return
        }
        DispatchQueue.main.async {
            self.updateUI(request, response: jsonResponse, error: nil)
        }
    }
    
    func handleError(request: RestRequest, error: RestClientError) {
        switch error {
            case .apiFailed(_, let underlyingError, _):
                SalesforceLogger.e(RootViewController.self, message: "Error invoking api \(underlyingError.localizedDescription)")
            default:
                DispatchQueue.main.async {
                    self.updateUI(request, response: nil, error: error)
                }
        }
    }
    
    @objc func userDidTapExpandButton(_ sender: UIButton) {
        UIView.animate(withDuration: 0.35, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: .curveEaseIn, animations: {
            if self.responseContractedTopConstraint.isActive {
                self.responseContractedTopConstraint.isActive = false
                self.responseExpandedTopConstraint.isActive = true
                sender.transform = CGAffineTransform(rotationAngle: .pi)
            } else {
                sender.transform = CGAffineTransform(rotationAngle: 0)
                self.responseExpandedTopConstraint.isActive = false
                self.responseContractedTopConstraint.isActive = true
            }
            self.view.layoutIfNeeded()
        }) { _ in
            self.view.layoutIfNeeded()
        }
    }
    
    func showMissingFieldError(_ reason: String?) {
        guard let rsn = reason else {return}
        self.showAlert("Missing Fields", message: "You need to fill out the following field(s): \(rsn)")
    }
    
    func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Ok", style: .default) { _ in
            self.presentedViewController?.dismiss(animated: true, completion: nil)
        }
        alert.addAction(cancel)
        self.present(alert, animated: true, completion: nil)
    }
    
    func createLogoutActionSheet() {
        let alert = UIAlertController(title: nil,
                                      message: "Are you sure you want to log out?",
                                      preferredStyle: .alert)
        
        let logout = UIAlertAction(title: "Logout", style: .default) { _ in
            UserAccountManager.shared.logout()
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.presentedViewController?.dismiss(animated: true, completion: nil)
        }
        alert.addAction(cancel)
        alert.addAction(logout)
        self.present(alert, animated: true, completion: nil)
        self.logoutAlert = alert
    }
    
    @objc func clearPopoversForPasscode() {
        SalesforceLogger.log(RootViewController.self, level: .debug, message: "Passcode screen loading. Clearing popovers")
        
        if let alert = self.logoutAlert {
            alert.dismiss(animated: true, completion: nil)
        }
        
        self.dismissPopover()
    }
    
    func dismissPopover() {
        if let pAction = self.presentedActions {
            pAction.dismiss(animated: true, completion: nil)
        }
    }
    
    func exportTestingCredentials() {
        if let appDelegate = SFApplicationHelper.sharedApplication()?.delegate as? AppDelegate {
            appDelegate.exportTestingCredentials()
        }
    }
    
    func updateUI(_ forRequest: RestRequest, response: Any?, error: Error?) {
        self.manualQueryTextField.text = forRequest.path
        self.paramsTextView.text = SFJsonUtils.jsonRepresentation(forRequest.queryParams as Any)
        self.methodControl.selectedSegmentIndex = forRequest.method.rawValue
        
        guard let largeFont = UIFont.appRegularFont(20), let regFont = UIFont.appRegularFont(14) else {return}
        let titleAttribs: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: largeFont,
                                                          NSAttributedString.Key.foregroundColor: UIColor.appTextField]

        let descriptionAttribs: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: regFont,
                                                                NSAttributedString.Key.foregroundColor: UIColor.appTextField]
        
        let attributedString = NSMutableAttributedString(string: "Response for: ", attributes: titleAttribs)
        
        let description = forRequest.description.replacingOccurrences(of: "\n", with: "")
        let descriptionString = NSAttributedString(string: description, attributes: descriptionAttribs)
        attributedString.append(descriptionString)
        self.responseSection.attributedTitle = attributedString
        
        if let resp = response {
            let jsonData = try? JSONSerialization.data(withJSONObject: resp, options: .prettyPrinted)
            if let jsonObj = jsonData {
                let jsonString = String(data: jsonObj, encoding: .utf8)
                self.responseForTextView.setContentOffset(CGPoint.zero, animated: false)
                self.responseForTextView.text = jsonString
            }
        }
        
        if let err = error {
            self.responseForTextView.text = err.localizedDescription
        }
        
    }
}

extension RootViewController: ActionTableViewDelegate {
    
    func userDidSelectAction(_ action: Action) {
        self.dismissPopover()
        self.handleAction(action)
    }
    
    func handleAction(_ action: Action) {
        let objectTypes = action.objectTypes
        var request: RestRequest?
        
        let objectType = self.objectTypeTextField.text
        let objectId = self.objectIdTextField.text
        let fieldList = self.fieldListTextField.text
        let objectList = self.objectListTextField.text
        let fields = SFJsonUtils.object(fromJSONString: self.fieldsTextView.text) as? [String: Any]
        let search = self.searchTextField.text
        let query = self.queryTextField.text
        let externalId = self.externalIdTextField.text
        let externalFieldId = self.externalFieldIdTextField.text
        let userId = self.userIdTextField.text
        let page = UInt(self.pageTextField.text ?? "")
        let objectIdList = self.objectIdListTextField.text?.components(separatedBy: ",")
        let entityId = self.entityIdTextField.text
        let shareType = self.shareTypeTextField.text
        let restApi = RestClient.shared
        
        switch action.type {
        case .versions:
            request = restApi.requestForVersions()
        case .resources:
            request =  restApi.request(forResources: SFRestDefaultAPIVersion)
        case .describeGlobal:
            request = restApi.request(forDescribeGlobal: SFRestDefaultAPIVersion)
        case .metadataWithObjectType:
            guard let objType = objectType else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.requestForMetadata(withObjectType: objType, apiVersion: SFRestDefaultAPIVersion)
        case .describeWithObjectType:
            guard let objType = objectType else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.requestForDescribe(withObjectType: objType, apiVersion: SFRestDefaultAPIVersion)
        case .retrieveWithObjectType:
            guard let objType = objectType, let objId = objectId, let fList = fieldList else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.requestForRetrieve(withObjectType: objType, objectId: objId, fieldList: fList, apiVersion: SFRestDefaultAPIVersion)
        case .createWithObjectType:
            guard let objType = objectType, let flds = fields else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.requestForCreate(withObjectType: objType, fields: flds, apiVersion: SFRestDefaultAPIVersion)
        case .upsertWithObjectType:
            guard let objType = objectType, let extFId = externalFieldId, let extId = externalId, let flds = fields else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request =  restApi.requestForUpsert(withObjectType: objType, externalIdField: extFId, externalId: extId, fields: flds, apiVersion: SFRestDefaultAPIVersion)
        case .updateWithObjectType:
            guard let objType = objectType, let objId = objectId, let flds = fields else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.requestForUpdate(withObjectType: objType, objectId: objId, fields: flds, apiVersion: SFRestDefaultAPIVersion)
        case .deleteWithObjectType:
            guard let objType = objectType, let objId = objectId else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.requestForDelete(withObjectType: objType, objectId: objId, apiVersion: SFRestDefaultAPIVersion)
        case .query:
            guard let qry = query else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.request(forQuery: qry, apiVersion: SFRestDefaultAPIVersion)
        case .search:
            guard let srch = search else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.request(forSearch: srch, apiVersion: SFRestDefaultAPIVersion)
        case .searchScopeAndOrder:
            request = restApi.request(forSearchScopeAndOrder: SFRestDefaultAPIVersion)
        case .searchResultLayout:
            guard let objList = objectList else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.request(forSearchResultLayout: objList, apiVersion: SFRestDefaultAPIVersion)
        case .ownedFilesList:
            guard let uId = userId, let pge = page else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.request(forOwnedFilesList: uId, page: pge, apiVersion: SFRestDefaultAPIVersion)
        case .filesInUserGroups:
            guard let uId = userId, let pge = page else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.requestForFiles(inUsersGroups: uId, page: pge, apiVersion: SFRestDefaultAPIVersion)
        case .filesSharedWithUser:
            guard let uId = userId, let pge = page else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.requestForFilesShared(withUser: uId, page: pge, apiVersion: SFRestDefaultAPIVersion)
        case .fileDetails:
            guard let objId = objectId else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.request(forFileDetails: objId, forVersion: objId, apiVersion: SFRestDefaultAPIVersion)
        case .batchFileDetails:
            guard let objIdList = objectIdList else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.request(forBatchFileDetails: objIdList, apiVersion: SFRestDefaultAPIVersion)
        case .fileShares:
            guard let objId = objectId, let pge = page else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.request(forFileShares: objId, page: pge, apiVersion: SFRestDefaultAPIVersion)
            
        case .addFileShare:
            guard let objId = objectId, let eId = entityId, let sType = shareType else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.request(forAddFileShare: objId, entityId: eId, shareType: sType, apiVersion: SFRestDefaultAPIVersion)
        case .deleteFileShare:
            guard let objId = objectId else {
                self.showMissingFieldError(objectTypes)
                return
            }
            request = restApi.request(forDeleteFileShare: objId, apiVersion: SFRestDefaultAPIVersion)
        case .primingRecords:
            request = restApi.request(forPrimingRecords: nil, changedAfterTimestamp: nil, apiVersion: SFRestDefaultAPIVersion)
        case .currentUserInfo:
            guard let currentAccount = UserAccountManager.shared.currentUserAccount else {return}
            let idData = currentAccount.idData
            var userInfoString = "Name: " + self.fullName
            userInfoString += "\nID: " + idData.username
            userInfoString += "\nEmail: " + idData.email
            self.showAlert("User Info", message: userInfoString)
            return
        case .logout:
            self.presentedViewController?.dismiss(animated: true, completion: nil)
            self.createLogoutActionSheet()
            return
        case .switchUser:
            let umvc = SalesforceUserManagementViewController.init(completionBlock: { _ in
                self.dismiss(animated: true, completion: nil)
            })
            self.present(umvc, animated: true, completion: nil)
            return
        case .exportCredentials:
            self.exportTestingCredentials()
            return
        case .overrideStyleLight:
            SFSDKWindowManager.shared().userInterfaceStyle = .light
            return
        case .overrideStyleDark:
            SFSDKWindowManager.shared().userInterfaceStyle = .dark
            return
        case .overrideStyleUnspecified:
            SFSDKWindowManager.shared().userInterfaceStyle = .unspecified
            return
        }
        
        if let sendRequest = request {
            RestClient.shared.send(request: sendRequest) { result in
                switch result {
                    case .success(let response):
                        self.handleSuccess(request: sendRequest, response: response)
                    case .failure(let error):
                        self.handleError(request: sendRequest, error: error)
                }
            }
        }
    }
}
