//
//  ContactTableViewCell.swift
//  SmartSyncExplorerSwift
//
//  Created by Nicholas McDonald on 1/22/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//
/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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
