#ifndef SalesforceSDKConstants_h
#define SalesforceSDKConstants_h

#define FIX_CATEGORY_BUG(name) @interface FIXCATEGORYBUG ## name @end @implementation FIXCATEGORYBUG ## name @end 
#define SFRelease(ivar) [ivar release]; ivar = nil;

#ifdef __clang__
#define SFSDK_DEPRECATED(version, msg) __attribute__((deprecated("Deprecated in Salesforce Mobile SDK " #version ". " msg)))
#else
#define SFSDK_DEPRECATED(version, msg) __attribute__((deprecated()))
#endif

#endif // SalesforceSDKConstants_h