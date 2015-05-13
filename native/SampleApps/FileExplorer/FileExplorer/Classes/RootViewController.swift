/*
Copyright (c) 2014, salesforce.com, inc. All rights reserved.

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

import Foundation

class RootViewController : UITableViewController, SFRestDelegate
{
    var dataRows = [NSDictionary]()
    
    // very basic in-memory cache
    var thumbnailCache = [String : UIImage]()
    
    // MARK: - View lifecycle
    override func loadView()
    {
        super.loadView()
        self.title = "FileExplorer"
        let logoutButton = UIBarButtonItem(title: "Logout", style: .Plain, target: self, action: "logout")
        let cancelRequestsButton = UIBarButtonItem(title: "Cancel", style: .Plain, target: self, action: "cancelRequests")
        self.navigationItem.leftBarButtonItems = [logoutButton, cancelRequestsButton]
        let ownedFilesButton = UIBarButtonItem(title: "Owned", style: .Plain, target: self, action: "showOwnedFiles")
        let groupsFilesButton = UIBarButtonItem(title: "Groups", style: .Plain, target: self, action: "showGroupsFiles")
        let sharedFilesButton = UIBarButtonItem(title: "Shared", style: .Plain, target: self, action: "showSharedFiles")
        self.navigationItem.rightBarButtonItems = [ownedFilesButton, groupsFilesButton, sharedFilesButton]
    }
    
    // MARK: - Button handlers
    func logout()
    {
        SFAuthenticationManager.sharedManager().logout()
    }
    
    func cancelRequests()
    {
        SFRestAPI.sharedInstance().cancelAllRequests()
    }
    
    func showOwnedFiles()
    {
        let request = SFRestAPI.sharedInstance().requestForOwnedFilesList(nil, page: 0)
        SFRestAPI.sharedInstance().send(request, delegate: self)
    }
    
    func showGroupsFiles()
    {
        let request = SFRestAPI.sharedInstance().requestForFilesInUsersGroups(nil, page: 0)
        SFRestAPI.sharedInstance().send(request, delegate: self)
    }
    
    func showSharedFiles()
    {
        let request = SFRestAPI.sharedInstance().requestForFilesSharedWithUser(nil, page: 0)
        SFRestAPI.sharedInstance().send(request, delegate: self)
    }
    
    // MARK: - SFRestAPIDelegate
    func request(request: SFRestRequest!, didLoadResponse jsonResponse: AnyObject!)
    {
        self.dataRows = jsonResponse["files"] as! [NSDictionary]
        self.log(SFLogLevelDebug, msg: "request:didLoadResponse: #files: \(self.dataRows.count)")
        dispatch_async(dispatch_get_main_queue(), {
            self.tableView.reloadData()
        })
    }
    
    func request(request: SFRestRequest!, didFailLoadWithError error: NSError!)
    {
        self.log(SFLogLevelDebug, msg: "didFailLoadWithError: \(error)")
    }
    
    func requestDidCancelLoad(request: SFRestRequest!)
    {
        self.log(SFLogLevelDebug, msg: "requestDidCancelLoad: \(request)")
    }
    
    func requestDidTimeout(request: SFRestRequest!)
    {
        self.log(SFLogLevelDebug, msg: "requestDidTimeout: \(request)")
    }
    
    // MARK: - Thumbnail handling
    /**
     * Return image from cache if available, otherwise download image from server, and then size it and cache it
     */
    func getThumbnail(fileId:String, completeBlock:(UIImage!) -> Void)
    {
        // cache hit
        if let cachedImage = self.thumbnailCache[fileId] {
            completeBlock(cachedImage)
        }
            // cache miss
        else {
            self.downloadThumbnail(fileId, completeBlock:{
                [weak self]
                image in
                // size it
                UIGraphicsBeginImageContext(CGSizeMake(120,90))
                image.drawInRect(CGRectMake(0, 0, image.size.width, 90))
                let thumbnailImage = UIGraphicsGetImageFromCurrentImageContext() as UIImage
                UIGraphicsEndImageContext()
                // cache it
                self!.thumbnailCache[fileId] = thumbnailImage
                // done
                completeBlock(thumbnailImage);
            })
        }
    }
    
    func downloadThumbnail(fileId:String, completeBlock:(UIImage!) -> Void)
    {
        SFRestAPI.sharedInstance().performRequestForFileRendition(fileId, version: nil, renditionType: "THUMB120BY90", page: 0, failBlock: nil, completeBlock: {
                responseData in
                self.log(SFLogLevelDebug, msg:"downloadThumbnail:\(fileId) completed")
                let image = UIImage(data: responseData)
                dispatch_async(dispatch_get_main_queue(), {
                    completeBlock(image)
                })
            })
    }
    
    // MARK: - Table view data source
    override func numberOfSectionsInTableView(tableView: UITableView?) -> Int
    {
        return 1
    }
    
    override func tableView(tableView: UITableView?, numberOfRowsInSection section: Int) -> Int
    {
        return self.dataRows.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cellIdentifier = "CellIdentifier"

        // Dequeue or create a cell of the appropriate type.
        var cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as? UITableViewCell
        if (cell == nil)
        {
            cell = UITableViewCell(style: .Subtitle, reuseIdentifier: cellIdentifier)
        }
        
        // Configure the cell to show the data.
        let obj = dataRows[indexPath.row]
        let fileId = obj["id"] as! String
        let tag = fileId.hash
        
        cell!.textLabel!.text =  obj["title"] as? String
        cell!.detailTextLabel!.text = (obj["owner"] as! NSDictionary)["name"] as? String
        cell!.tag = tag;
        self.getThumbnail(fileId, completeBlock: {
            thumbnailImage in
            // Cell are recycled - we don't want to set the image if the cell is showing a different file
            if (cell!.tag == tag)
            {
                cell!.imageView!.image = thumbnailImage
                cell!.setNeedsLayout()
            }
        })
        
        return cell!
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
        return 90
    }
}
