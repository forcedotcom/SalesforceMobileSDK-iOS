#ifndef SalesforceSDKConstants_h
#define SalesforceSDKConstants_h

#define SALESFORCE_SDK_IS_PRODUCTION_VERSION YES

#define SALESFORCE_SDK_BUILD_IDENTIFIER @".dev"

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
#define __SALESFORCE_SDK_5_0_0 50000
#define __SALESFORCE_SDK_5_0_1 50001
#define __SALESFORCE_SDK_5_1_0 50100
#define __SALESFORCE_SDK_5_2_0 50200
#define __SALESFORCE_SDK_5_3_0 50300
#define __SALESFORCE_SDK_5_3_1 50301
#define __SALESFORCE_SDK_6_0_0 60000
#define __SALESFORCE_SDK_6_1_0 60100
#define __SALESFORCE_SDK_6_2_0 60200
#define __SALESFORCE_SDK_7_0_0 70000
#define __SALESFORCE_SDK_7_1_0 70100

#define SALESFORCE_SDK_VERSION_MIN_REQUIRED __SALESFORCE_SDK_7_1_0

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
#define SFSDK_DEPRECATED(dep_version, rem_version, msg) __attribute__((deprecated("Deprecated in Salesforce Mobile SDK " #dep_version " and will be removed in Salesforce Mobile SDK " #rem_version ". " msg)))
#else
#define SFSDK_DEPRECATED(dep_version, rem_version, msg) __attribute__((deprecated()))
#endif

#define SFSDK_USE_DEPRECATED_BEGIN \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")

#define SFSDK_USE_DEPRECATED_END \
_Pragma("clang diagnostic pop")


/*!
 * @function sf_os_signpost_interval_begin
 *
 * @abstract
 * Begins a signposted interval.
 *
 * @param log
 * Log handle previously created with os_log_create.
 *
 * @param interval_id
 * An ID for the event, see Signpost IDs above.
 *
 * @param name
 * The name of this event. This must be a string literal.
 *
 * @param ... (format + arguments)
 * Additional information to include with this signpost.  This format string
 * must be a string literal, as with the os_log family of functions.
 */
#define sf_os_signpost_interval_begin(log, interval_id, name, ...) \
if (@available(iOS 12.0, *)) { \
    os_signpost_emit_with_type(log, OS_SIGNPOST_INTERVAL_BEGIN, interval_id, name, ##__VA_ARGS__); \
}


/*!
 * @function sf_os_signpost_interval_end
 *
 * @abstract
 * Ends a signposted interval.
 *
 * @param log
 * The log handle which was provided to os_signpost_interval_begin,
 *
 * @param interval_id
 * The ID for the event which was provided to os_signpost_interval_begin.  See
 * Signpost IDs above.
 *
 * @param name
 * The name of the event provided to os_signost_interval_begin. This must be a
 * string literal.
 *
 * @param ... (format + arguments)
 * Additional information to include with this signpost.  This format string
 * must be a string literal, as with the os_log family of functions.
 */
#define sf_os_signpost_interval_end(log, interval_id, name, ...) \
if (@available(iOS 12.0, *)) { \
    os_signpost_emit_with_type(log, OS_SIGNPOST_INTERVAL_END, interval_id, name, ##__VA_ARGS__); \
}

#define sf_os_signpost_id_generate(log) \
({ os_signpost_id_t sid = OS_SIGNPOST_ID_INVALID; \
    if (@available(iOS 12.0, *)) { \
        sid = os_signpost_id_generate(log); \
    }\
    sid; \
})

#endif // SalesforceSDKConstants_h
