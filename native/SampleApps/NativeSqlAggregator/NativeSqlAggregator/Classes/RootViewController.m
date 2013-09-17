/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 
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

#import "RootViewController.h"

#import <SalesforceNativeSDK/SFRestAPI.h>
#import <SalesforceNativeSDK/SFRestRequest.h>
#import "SmartStoreInterface.h"
#import "ResultViewController.h"

@implementation RootViewController

@synthesize smartStoreIntf;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        smartStoreIntf = [[SmartStoreInterface alloc] init];
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    self.smartStoreIntf = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"NativeSqlAggregator";
}

- (void)request:(SFRestRequest *)request didLoadResponse:(id)dataResponse
{
    NSArray *records = [dataResponse objectForKey:@"records"];
    if (nil != records) {
        NSDictionary *firstRecord = [records objectAtIndex:0];
        if (nil != firstRecord) {
            NSDictionary *attributes = [firstRecord valueForKey:@"attributes"];
            if (nil != attributes) {
                NSString *type = [attributes valueForKey:@"type"];
                if ([type isEqual:@"Account"]) {
                    [self.smartStoreIntf insertAccounts:records];
                } else if ([type isEqual:@"Opportunity"]) {
                    [self.smartStoreIntf insertOpportunities:records];
                } else {

                    /*
                     * If the object is not an account or opportunity,
                     * we do nothing. This block can be used to save
                     * other types of records.
                     */
                }
            }
        }
    }
}

- (void)request:(SFRestRequest*)request didFailLoadWithError:(NSError*)error
{
    NSLog(@"REST request failed with error: %@", error);
}

- (void)requestDidCancelLoad:(SFRestRequest *)request
{
    NSLog(@"REST request canceled. Request: %@", request);
}

- (void)requestDidTimeout:(SFRestRequest *)request
{
    NSLog(@"REST request timed out. Request: %@", request);
}

- (IBAction)btnSaveRecOfflinePressed:(id)sender
{
    [self.smartStoreIntf createAccountsSoup];
    [self.smartStoreIntf createOpportunitiesSoup];
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:@"SELECT Name, Id, OwnerId FROM Account"];
    [[SFRestAPI sharedInstance] send:request delegate:self];
    request = [[SFRestAPI sharedInstance] requestForQuery:@"SELECT Name, Id, AccountId, OwnerId, Amount FROM Opportunity"];
    [[SFRestAPI sharedInstance] send:request delegate:self];
}

- (IBAction)btnClearOfflineStorePressed:(id)sender
{
    [self.smartStoreIntf deleteAccountsSoup];
    [self.smartStoreIntf deleteOpportunitiesSoup];
    [self.smartStoreIntf createAccountsSoup];
    [self.smartStoreIntf createOpportunitiesSoup];
}

- (IBAction)btnRunReportPressed:(id)sender
{
    NSArray *results = [self.smartStoreIntf query:kAggregateQueryStr];
    ResultViewController *resultVC = [[ResultViewController alloc] initWithNibName:nil bundle:nil];
    [resultVC setResultDataSet:results];
    [[self navigationController] pushViewController:resultVC animated:YES];
}

@end
