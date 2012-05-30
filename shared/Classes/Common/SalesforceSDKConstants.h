#ifndef SalesforceSDKConstants_h
#define SalesforceSDKConstants_h

#define FIX_CATEGORY_BUG(name) @interface FIXCATEGORYBUG ## name @end @implementation FIXCATEGORYBUG ## name @end 
#define SFRelease(ivar) [ivar release]; ivar = nil;

#endif // SalesforceSDKConstants_h