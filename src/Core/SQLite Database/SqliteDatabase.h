/*
 This file is part of Mac Eve Tools.
 
 Mac Eve Tools is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 Mac Eve Tools is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with Mac Eve Tools.  If not, see <http://www.gnu.org/licenses/>.
 
 Copyright Matt Tyson, 2009.
 */
#import <Cocoa/Cocoa.h>

typedef struct sqlite3 sqlite3;

@interface SqliteDatabase : NSObject {
	sqlite3 *db;
	NSString *databasePath;
	NSInteger pathLength;
	char *path;
}

-(id) initWithPath:(NSString*)path;

-(void) logError:(char*)errmsg;

-(sqlite3 *) openDatabase;
-(void) closeDatabase;

-(BOOL) beginTransaction;
-(BOOL) commitTransaction;
-(BOOL) rollbackTransaction;

-(BOOL) doesTableExist:(NSString *)tableName;
-(BOOL) doesTable:(NSString *)tableName haveColumn:(NSString *)colName;
-(NSInteger) performCount:(const char*)query;

@end
