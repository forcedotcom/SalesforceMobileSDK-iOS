//
//  ViewController.swift
//  RestAPIExplorerSwift
//
//  Created by Nicholas McDonald on 1/3/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

import UIKit

class InitialViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.white
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        guard let info = Bundle.main.infoDictionary, let name = info[kCFBundleNameKey as String] else { return }
        label.font = UIFont.systemFont(ofSize: 29)
        label.textColor = UIColor.black
        label.text = name as? String
        
        self.view.addSubview(label)
        label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

