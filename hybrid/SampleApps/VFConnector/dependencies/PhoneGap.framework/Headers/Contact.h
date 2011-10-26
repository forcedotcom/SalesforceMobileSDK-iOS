/*
 * PhoneGap is available under *either* the terms of the modified BSD license *or* the
 * MIT License (2008). See http://opensource.org/licenses/alphabetical for full text.
 * 
 * Copyright (c) 2005-2010, Nitobi Software Inc.
 * Copyright (c) 2010, IBM Corporation
 */

#import <Foundation/Foundation.h>
#import <AddressBook/ABAddressBook.h>
#import <AddressBookUI/AddressBookUI.h>



enum ContactError {
	UNKNOWN_ERROR = 0,
	INVALID_ARGUMENT_ERROR = 1,
	TIMEOUT_ERROR = 2,
	PENDING_OPERATION_ERROR = 2,
	IO_ERROR = 4,
	NOT_SUPPORTED_ERROR = 5,
	PERMISSION_DENIED_ERROR = 20
};
typedef NSUInteger ContactError;

@interface PGContact : NSObject {
	
	ABRecordRef record;			// the ABRecord associated with this contact
	NSDictionary* returnFields;	// dictionary of fields to return when performing search
} 

@property (nonatomic, assign) ABRecordRef record;
@property (nonatomic, retain) NSDictionary* returnFields;

+(NSDictionary*) defaultABtoW3C;
+(NSDictionary*) defaultW3CtoAB;
+(NSSet*) defaultW3CtoNull;
+(NSDictionary*) defaultObjectAndProperties;
+(NSDictionary*) defaultFields;
+(void) releaseDefaults;


+(NSDictionary*) calcReturnFields: (NSArray*)fields;
-(id)init;
-(id)initFromABRecord: (ABRecordRef) aRecord;
-(bool) setFromContactDict:(NSMutableDictionary*) aContact asUpdate: (BOOL)bUpdate;

+(BOOL) needsConversion: (NSString*)W3Label;
+(CFStringRef) convertContactTypeToPropertyLabel:(NSString*)label;
+(NSString*) convertPropertyLabelToContactType: (NSString*)label;
+(BOOL) isValidW3ContactType: (NSString*) label;
-(bool) setValue: (id)aValue forProperty: (ABPropertyID) aProperty inRecord: (ABRecordRef) aRecord asUpdate: (BOOL)bUpdate;

-(NSDictionary*) toDictionary: (NSDictionary*) withFields;
-(NSNumber*)getDateAsNumber: (ABPropertyID) datePropId;	
-(NSObject*) extractName;
-(NSObject*) extractMultiValue: (NSString*)propertyId;
-(NSObject*) extractAddresses;
-(NSObject*) extractIms;
-(NSObject*) extractOrganizations;
-(NSObject*) extractPhotos;

-(NSMutableDictionary*) translateW3Dict: (NSDictionary*) dict forProperty: (ABPropertyID) prop;	
-(bool) setMultiValueStrings: (NSArray*)fieldArray forProperty: (ABPropertyID) prop inRecord: (ABRecordRef)person asUpdate: (BOOL)bUpdate;
-(bool) setMultiValueDictionary: (NSArray*)array forProperty: (ABPropertyID) prop inRecord: (ABRecordRef)person asUpdate: (BOOL)bUpdate;
-(ABMultiValueRef) allocStringMultiValueFromArray: array;
-(ABMultiValueRef) allocDictMultiValueFromArray: array forProperty: (ABPropertyID) prop;
-(BOOL) foundValue: (NSString*)testValue inFields: (NSDictionary*) searchFields;
-(BOOL) testStringValue: (NSString*) testValue forW3CProperty:(NSString*) property;
-(BOOL) testDateValue: (NSString*)testValue forW3CProperty: (NSString*) property;
-(BOOL) searchContactFields: (NSArray*) fields forMVStringProperty: (ABPropertyID) propId withValue: testValue;
- (BOOL) testMultiValueStrings: (NSString*) testValue forProperty: (ABPropertyID) propId ofType: (NSString*) type;
- (NSArray *) valuesForProperty: (ABPropertyID) propId inRecord: (ABRecordRef) aRecord;
- (NSArray *) labelsForProperty: (ABPropertyID) propId inRecord: (ABRecordRef)aRecord;
-(BOOL) searchContactFields: (NSArray*) fields forMVDictionaryProperty: (ABPropertyID) propId withValue: (NSString*)testValue;

- (void) dealloc;	


@end

// generic ContactField types
#define kW3ContactFieldType @"type"
#define kW3ContactFieldValue @"value"
#define kW3ContactFieldPrimary @"pref"
// Various labels for ContactField types
#define kW3ContactWorkLabel @"work"
#define kW3ContactHomeLabel @"home"
#define kW3ContactOtherLabel @"other"
#define kW3ContactPhoneFaxLabel @"fax"
#define kW3ContactPhoneMobileLabel @"mobile"
#define kW3ContactPhonePagerLabel @"pager"
#define kW3ContactUrlBlog @"blog"
#define kW3ContactUrlProfile @"profile"
#define kW3ContactImAIMLabel @"aim"
#define kW3ContactImICQLabel @"icq"
#define kW3ContactImMSNLabel @"msn"
#define kW3ContactImYahooLabel @"yahoo"
#define kW3ContactFieldId @"id"
// special translation for IM field value and type
#define kW3ContactImType @"type"
#define kW3ContactImValue @"value"

// Contact object
#define kW3ContactId @"id"
#define kW3ContactName @"name"
#define kW3ContactFormattedName @"formatted"
#define kW3ContactGivenName @"givenName"
#define kW3ContactFamilyName @"familyName"
#define kW3ContactMiddleName @"middleName"
#define kW3ContactHonorificPrefix @"honorificPrefix"
#define kW3ContactHonorificSuffix @"honorificSuffix"
#define kW3ContactDisplayName @"displayName"
#define kW3ContactNickname @"nickname"
#define kW3ContactPhoneNumbers @"phoneNumbers"
#define kW3ContactAddresses @"addresses"
#define kW3ContactAddressFormatted @"formatted"
#define kW3ContactStreetAddress @"streetAddress"
#define kW3ContactLocality @"locality"
#define kW3ContactRegion @"region"
#define kW3ContactPostalCode @"postalCode"
#define kW3ContactCountry @"country"
#define kW3ContactEmails @"emails"
#define kW3ContactIms @"ims"
#define kW3ContactOrganizations @"organizations"
#define kW3ContactOrganizationName @"name"
#define kW3ContactTitle @"title"
#define kW3ContactDepartment @"department"
#define kW3ContactBirthday @"birthday"
#define kW3ContactNote @"note"
#define kW3ContactPhotos @"photos"
#define kW3ContactCategories @"categories"
#define kW3ContactUrls @"urls"


