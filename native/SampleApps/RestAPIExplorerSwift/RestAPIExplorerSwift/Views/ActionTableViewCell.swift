//
//  ActionTableViewCell.swift
//  RestAPIExplorerSwift
//
//  Created by Nicholas McDonald on 1/10/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

import UIKit

class ActionTableViewCell: UITableViewCell {
    
    var actionLabel = UILabel()
    var objectLabel = UILabel()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.actionLabel.translatesAutoresizingMaskIntoConstraints = false
        self.objectLabel.translatesAutoresizingMaskIntoConstraints = false
        
        self.actionLabel.font = UIFont.appBoldFont(14)
        self.actionLabel.textColor = UIColor.appTextFieldBlue
        self.objectLabel.font = UIFont.appRegularFont(12)
        self.objectLabel.textColor = UIColor.appTextFieldBlue
        
        self.contentView.addSubview(self.actionLabel)
        self.contentView.addSubview(self.objectLabel)
        
        self.actionLabel.leftAnchor.constraint(equalTo: self.contentView.leftAnchor, constant:10).isActive = true
        self.actionLabel.bottomAnchor.constraint(equalTo: self.contentView.centerYAnchor).isActive = true
        self.objectLabel.leftAnchor.constraint(equalTo: self.actionLabel.leftAnchor).isActive = true
        self.objectLabel.topAnchor.constraint(equalTo: self.actionLabel.bottomAnchor).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
