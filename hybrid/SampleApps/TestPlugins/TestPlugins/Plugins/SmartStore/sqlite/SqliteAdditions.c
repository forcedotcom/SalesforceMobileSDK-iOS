/*
 * Copyright, 2008, salesforce.com
 * All Rights Reserved
 * Company Confidential
 */


#include "SqliteAdditions.h"

#include <string.h>

//prototypes
char *trim_right( char *szSource, char tobeTrimed );
char *trim_left( char *szSource, char tobeTrimed );
char *trim( char *szSource, char tobeTrimed );
void concat_free(void* result);


char *trim_right( char *szSource, char tobeTrimed ) {
	if(strlen(szSource) == 0)
		return szSource;
	
	char *pszEOS = 0;
	
	// Set pointer to character before terminating NULL
	pszEOS = szSource + strlen( szSource ) - 1;
	
	// iterate backwards until non 'tobeTrimed' is found 
	while( (pszEOS >= szSource) && (*pszEOS == tobeTrimed) )
		*pszEOS-- = '\0';
	
	return szSource;
}

char *trim_left( char *szSource, char tobeTrimed ) {
	int i;
	int szLen = strlen(szSource);
	
	for(i=0 ; i<szLen-1; i++) {
		if(szSource[i] != tobeTrimed)
			break;
	}
	
	if(i > 0)
		memmove(szSource, szSource+i, szLen-i+1);
	
	return szSource;
}

char *trim( char *szSource, char tobeTrimed ) {
	return trim_left(trim_right(szSource,tobeTrimed),tobeTrimed);
}

void concat_free(void* result) {
	sqlite3_free((char*)result);
}

void concat(sqlite3_context* ctx, int nargs, sqlite3_value** values) {
	char *result = NULL;
	int totalLen = 0;
	for(int i=0; i<nargs; i++) {
		if (sqlite3_value_text(values[i]) != NULL) {
			totalLen = totalLen + strlen((char*)sqlite3_value_text(values[i]));
		}
	}
	totalLen++;
	result = sqlite3_malloc(totalLen);
	if (result == NULL) {
		return;
	}
	result[0] = '\0';
	for(int i=0; i<nargs; i++) {
		if (sqlite3_value_text(values[i]) != NULL) {
			strncat(result, (const char*)sqlite3_value_text(values[i]), totalLen);
		}
	}
	
	char *endResult = trim(result, ' ');
	endResult = trim(endResult, ',');
	
	sqlite3_result_text(ctx,endResult, -1, concat_free);

}
