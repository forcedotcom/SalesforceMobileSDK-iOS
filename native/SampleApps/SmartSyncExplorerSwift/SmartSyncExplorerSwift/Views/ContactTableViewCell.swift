//
//  ContactTableViewCell.swift
//  SmartSyncExplorerSwift
//
//  Created by Nicholas McDonald on 1/22/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

import UIKit

class ContactTableViewCell: UITableViewCell {
    
    var leftImage:UIImage? {
        didSet {
            self.leftImageView.image = leftImage
        }
    }
    var title:String? {
        didSet {
            self.titleLabel.text = title
        }
    }
    
    var subtitle:String? {
        didSet {
            self.detailLabel.text = subtitle
        }
    }
    
    var showRefresh:Bool = false {
        didSet {
            self.rightRefreshImageView.alpha = showRefresh ? 1.0 : 0.0
        }
    }
    
    fileprivate var leftImageView = UIImageView()
    fileprivate var titleLabel = UILabel()
    fileprivate var detailLabel = UILabel()
    fileprivate var rightRefreshImageView = UIImageView()
    fileprivate var rightArrowImageView = UIImageView()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.leftImageView.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.detailLabel.translatesAutoresizingMaskIntoConstraints = false
        self.rightRefreshImageView.translatesAutoresizingMaskIntoConstraints = false
        self.rightArrowImageView.translatesAutoresizingMaskIntoConstraints = false
        
        self.titleLabel.font = UIFont.appRegularFont(16)
        self.titleLabel.textColor = UIColor.contactCellTitle
        self.detailLabel.font = UIFont.appRegularFont(12)
        self.detailLabel.textColor = UIColor.contactCellSubtitle
        self.rightRefreshImageView.image = UIImage(named: "sync")
        self.rightArrowImageView.image = UIImage(named: "rightArrow")
        
        self.contentView.addSubview(self.leftImageView)
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.detailLabel)
        self.contentView.addSubview(self.rightRefreshImageView)
        self.contentView.addSubview(self.rightArrowImageView)
        
        self.leftImageView.leftAnchor.constraint(equalTo: self.contentView.leftAnchor, constant: 24).isActive = true
        self.leftImageView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor).isActive = true
        self.titleLabel.leftAnchor.constraint(equalTo: self.leftImageView.rightAnchor, constant: 24).isActive = true
        self.titleLabel.lastBaselineAnchor.constraint(equalTo: self.contentView.centerYAnchor, constant:-3).isActive = true
        self.detailLabel.leftAnchor.constraint(equalTo: self.titleLabel.leftAnchor).isActive = true
        self.detailLabel.topAnchor.constraint(equalTo: self.contentView.centerYAnchor, constant:3).isActive = true
        self.rightArrowImageView.rightAnchor.constraint(equalTo: self.contentView.rightAnchor, constant:-24).isActive = true
        self.rightArrowImageView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor).isActive = true
        self.rightRefreshImageView.rightAnchor.constraint(equalTo: self.rightArrowImageView.leftAnchor, constant: -10.0).isActive = true
        self.rightRefreshImageView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor).isActive = true
        self.rightRefreshImageView.heightAnchor.constraint(equalToConstant: 16.0).isActive = true
        self.rightRefreshImageView.widthAnchor.constraint(equalToConstant: 16.0).isActive = true
        
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
