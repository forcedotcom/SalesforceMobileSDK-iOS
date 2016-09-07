#ifndef SalesforceSDKConstants_h
#define SalesforceSDKConstants_h

#define SALESFORCE_SDK_IS_PRODUCTION_VERSION YES

#define SALESFORCE_SDK_BUILD_IDENTIFIER @".unstable"

#define __SALESFORCE_SDK_2_0_0 20000
#define __SALESFORCE_SDK_2_0_1 20001
#define __SALESFORCE_SDK_2_0_2 20002
#define __SALESFORCE_SDK_2_0_3 20003
#define __SALESFORCE_SDK_2_0_4 20004
#define __SALESFORCE_SDK_2_0_5 20005
#define __SALESFORCE_SDK_2_1_0 20100
#define __SALESFORCE_SDK_2_1_1 20101
#define __SALESFORCE_SDK_2_1_2 20102
#define __SALESFORCE_SDK_2_1_3 20103
#define __SALESFORCE_SDK_2_2_0 20200
#define __SALESFORCE_SDK_2_2_1 20201
#define __SALESFORCE_SDK_2_2_2 20202
#define __SALESFORCE_SDK_2_3_0 20300
#define __SALESFORCE_SDK_2_3_1 20301
#define __SALESFORCE_SDK_3_0_0 30000
#define __SALESFORCE_SDK_3_1_0 30100
#define __SALESFORCE_SDK_3_1_1 30101
#define __SALESFORCE_SDK_3_1_2 30102
#define __SALESFORCE_SDK_3_2_0 30200
#define __SALESFORCE_SDK_3_2_1 30201
#define __SALESFORCE_SDK_3_3_0 30300
#define __SALESFORCE_SDK_3_3_1 30301
#define __SALESFORCE_SDK_4_0_0 40000
#define __SALESFORCE_SDK_4_0_2 40002
#define __SALESFORCE_SDK_4_1_0 40100
#define __SALESFORCE_SDK_4_1_1 40101
#define __SALESFORCE_SDK_4_1_2 40102
#define __SALESFORCE_SDK_4_2_0 40200
#define __SALESFORCE_SDK_4_3_0 40300
#define __SALESFORCE_SDK_4_3_1 40301

#define SALESFORCE_SDK_VERSION_MIN_REQUIRED __SALESFORCE_SDK_4_3_1

#define SALESFORCE_SDK_VERSION [NSString stringWithFormat:@"%d.%d.%d%@",              \
                                (SALESFORCE_SDK_VERSION_MIN_REQUIRED / 10000),        \
                                (SALESFORCE_SDK_VERSION_MIN_REQUIRED % 10000) / 100,  \
                                (SALESFORCE_SDK_VERSION_MIN_REQUIRED % 10000) % 100,  \
                                (SALESFORCE_SDK_IS_PRODUCTION_VERSION ? @"" : SALESFORCE_SDK_BUILD_IDENTIFIER)]

#define FIX_CATEGORY_BUG(name) @interface FIXCATEGORYBUG ## name @end @implementation FIXCATEGORYBUG ## name @end
#define SFRelease(ivar) ivar = nil;

#define ABSTRACT_METHOD {\
[self doesNotRecognizeSelector:_cmd]; \
__builtin_unreachable(); \
}

#ifdef __clang__
#define SFSDK_DEPRECATED(version, msg) __attribute__((deprecated("Deprecated in Salesforce Mobile SDK " #version ". " msg)))
#else
#define SFSDK_DEPRECATED(version, msg) __attribute__((deprecated()))
#endif

#endif // SalesforceSDKConstants_h
