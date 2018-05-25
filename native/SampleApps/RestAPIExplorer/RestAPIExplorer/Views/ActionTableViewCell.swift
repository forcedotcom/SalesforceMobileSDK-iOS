/*
 ActionTableViewCell.swift
 RestAPIExplorerSwift

 Created by Nicholas McDonald on 1/10/18.

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
