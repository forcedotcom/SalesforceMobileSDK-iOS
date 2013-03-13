/*
 Copyright (c) 2008-2012, salesforce.com, inc. All rights reserved.
 
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

#include "SqliteAdditions.h"

#include <string.h>



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
