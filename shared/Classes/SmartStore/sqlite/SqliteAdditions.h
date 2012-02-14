/*
 * Copyright, 2008, salesforce.com
 * All Rights Reserved
 * Company Confidential
 */


#import "sqlite3.h"


void concat(sqlite3_context* ctx, int nargs, sqlite3_value** values);
//prototypes
char *trim_right( char *szSource, char tobeTrimed );
char *trim_left( char *szSource, char tobeTrimed );
char *trim( char *szSource, char tobeTrimed );
void concat_free(void* result);