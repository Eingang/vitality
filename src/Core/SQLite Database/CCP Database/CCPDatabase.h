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

#import "SqliteDatabase.h"
#import "macros.h"

#import <sqlite3.h>

@class CCPCategory;
@class CCPGroup;
@class CCPType;
@class METShip;
@class CertTree;
@class SkillTree;
@class CCPImplant;
@class METPair;

@interface CCPDatabase : SqliteDatabase {
	sqlite3_stmt *tran_stmt; //translation prepared statment
	enum DatabaseLanguage lang;
}

/*
	-1, nil or NO will be returned on error
 */

@property (readwrite,nonatomic,assign) enum DatabaseLanguage lang;

+ (NSInteger)dbVersion; ///< This is moderately expensive, currently only used by DBManager to determine if we need to update the db.

-(CCPDatabase*) initWithPath:(NSString*)dbpath;

//Database version
-(NSInteger) dbVersion;
-(NSString*) dbName;

// Write/read any data that needs to be saved across database updates (which really replace the database)
-(BOOL) preUpdate;
-(BOOL) postUpdate;

-(CCPCategory*) category:(NSInteger)categoryID;
/*return all categories*/
-(NSArray*) categoriesInDB;
-(NSInteger) categoryCount;

-(CCPGroup*) group:(NSInteger)groupID;
/*return an array of all the groups that exist in the category*/
-(NSArray*) groupsInCategory:(NSInteger)categoryID;
-(NSInteger) groupCount:(NSInteger)categoryID;

-(CCPType*) type:(NSInteger)typeID;
/*An array of all types in that group*/
-(NSArray*) typesInGroup:(NSInteger)groupID;
-(NSInteger) typeCount:(NSInteger)groupID;
-(NSString *) typeName:(NSInteger)typeID; // pulls from a pre-made table with typeID, typeName and description
-(NSString *) typeName:(NSInteger)typeID andDescription:(NSString **)desc; // pass in a nil for desc if you don't want it

-(NSArray*) prereqForType:(NSInteger) typeID;

/*given a typeID, what is it's parent typeID and metaGroup ?*/
-(BOOL) parentForTypeID:(NSInteger)typeID parentTypeID:(NSInteger*)parent metaGroupID:(NSInteger*)metaGroup;

/*get the metaLevel for the given typeID*/
-(NSInteger) metaLevelForTypeID:(NSInteger)typeID;

-(BOOL) isPirateShip:(NSInteger)typeID;

-(NSDictionary*) typeAttributesForTypeID:(NSInteger)typeID;


// Return all the attributes for a type of a particular group
-(NSArray*) attributeForType:(NSInteger)typeID groupBy:(enum AttributeTypeGroups)group;

-(CertTree*) buildCertTree;
-(SkillTree*) buildSkillTree;

// Simplified attribute type array for ship fitting
-(NSDictionary*) attributesForType:(NSInteger)typeID;

// Returns all the invTypes that require the given skillID
-(NSDictionary*) dependenciesForSkillByCategory:(NSInteger)typeID;

// Returns a dictionry for now, might turn into a class at some point
// @"name", @"stationID" and @"systemID" are the keys in the dictionary
- (NSDictionary *) stationForID:(NSInteger)stationID;

// Use this to add destructable station and player outpost names to the metStation table
- (void)insertStationID:(NSUInteger)stationID name:(NSString *)stationName system:(NSUInteger)solarSystemID;

/// Temporary hack for getting solar system and region names from a solar system ID. At some point we may need a full class. First is system name, second is region name.
- (METPair *) namesForSystemID:(NSInteger)systemID;

// Store Character, Corporation, Alliance and Mailing List ID's and names for use in contracts, mail, etc.
- (void)insertCharacterID:(NSUInteger)characterID name:(NSString *)name;
- (NSString *)characterNameForID:(NSInteger)characterID;

// Traits for a given type ID. Return array may be empty. Currently only for ships, I think.
-(NSArray *) traitsForTypeID:(NSInteger)typeID;

- (NSString *)nameForRace:(NSInteger)raceID;

// Given a type ID that represents an implant, create and return the implant
-(CCPImplant *) implantWithID:(NSInteger)typeID;
@end
