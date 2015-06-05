//
//  CharacterDatabase.m
//  Mac Eve Tools
//
//  Created by Matt Tyson on 6/06/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "CharacterDatabase.h"
#import "SkillPlan.h"
#import "CharacterDatabasePrivate.h"
#import "Character.h"
#import "macros.h"

/*database to store information about a character*/

#import <sqlite3.h>


/*
	main table
 
 int version ;database schema version
 varchar table_name ; name of a table, so tables can be versioned separately

	skill plan overview table

 int plan_id; plan id
 varchar plan_name;
 
	skill plan table
 int plan_id; the plan this skill belongs to
 int type_order; the order of this skill in the plan
 int type_id; the skills typeid (as used by the eve skill list xml sheet)
 int level; the rank we are training to
 
 */



@implementation CharacterDatabase

#define CURRENT_DB_VERSION 5

-(BOOL) createDatabase
{
	char *errmsg;
	char *strbuf;
	const char createMasterTable[] = "CREATE TABLE master (version INTEGER, table_name VARCHAR(32));";
	const char populateMasterTable[] = "INSERT INTO master (version,table_name) VALUES (%d,%Q);";
	const char createSkillPlanOverviewTable[] = 
			"CREATE TABLE skill_plan_overview (plan_id INTEGER PRIMARY KEY, plan_name VARCHAR(64), plan_order INTEGER, UNIQUE(plan_name));";
	const char createSkillPlanTable[] =
			"CREATE TABLE skill_plan (plan_id INTEGER, type_order INTEGER, type_id INTEGER, level INTEGER, note VARCHAR(1000), attribute_set_id INTEGER DEFAULT 0);";
	int rc;
	
	[self beginTransaction];
	
	rc = sqlite3_exec(db,createMasterTable,NULL,NULL,&errmsg);
	if(rc != SQLITE_OK){
		[self logError:errmsg];
		[self rollbackTransaction];
		return NO;
	}
	
	strbuf = sqlite3_mprintf(populateMasterTable,CURRENT_DB_VERSION,"master");
	rc = sqlite3_exec(db,strbuf,NULL,NULL,&errmsg);
	sqlite3_free(strbuf);
	
	if(rc != SQLITE_OK){
		[self logError:errmsg];
		[self rollbackTransaction];
		return NO;
	}
	
	rc = sqlite3_exec(db,createSkillPlanTable,NULL,NULL,&errmsg);
	if(rc != SQLITE_OK){
		[self logError:errmsg];
		[self rollbackTransaction];
		return NO;
	}
	
	rc = sqlite3_exec(db,createSkillPlanOverviewTable,NULL,NULL,&errmsg);
	if(rc != SQLITE_OK){
		[self logError:errmsg];
		[self rollbackTransaction];
		return NO;
	}
	
	[self commitTransaction];
	return YES;
}

-(BOOL) upgradeDatabaseFromVersion:(NSInteger)currentVersion 
						 toVersion:(NSInteger)toVersion
{
    if( currentVersion == toVersion )
    {
        return YES;
    }
    
    [self beginTransaction];

    if( (currentVersion >= 1) && (currentVersion <= 3) )
    {
        char *error = nil;
        int rc;
        // There's no way to change a column name, so we have to drop the table and recreate it.
        const char dropMasterTable[] = "DROP TABLE master;";
        const char createMasterTable[] = "CREATE TABLE master (version INTEGER, table_name VARCHAR(32));";
        
        rc = sqlite3_exec(db,dropMasterTable,NULL,NULL,&error);
        if(rc != SQLITE_OK){
            [self logError:error];
            [self rollbackTransaction];
            return NO;
        }
        
        rc = sqlite3_exec(db,createMasterTable,NULL,NULL,&error);
        if(rc != SQLITE_OK){
            [self logError:error];
            [self rollbackTransaction];
            return NO;
        }
        
        const char populateMasterTable[] = "INSERT INTO master (version,table_name) VALUES (%d,%Q);";
        char *strbuf = sqlite3_mprintf(populateMasterTable,CURRENT_DB_VERSION,"master");
        rc = sqlite3_exec(db,strbuf,NULL,NULL,&error);
        sqlite3_free(strbuf);
        
        if(rc != SQLITE_OK){
            [self logError:error];
            [self rollbackTransaction];
            return NO;
        }
        
        NSLog(@"Succesfully upgraded character database master table");
    }

    if(currentVersion == 1){
		const char rename[] = "ALTER TABLE skill_plan_overview RENAME TO skill_plan_overview_old;";
		const char createSkillPlanOverviewTable2[] = 
			"CREATE TABLE skill_plan_overview (plan_id INTEGER PRIMARY KEY, plan_name VARCHAR(64), plan_order INTEGER, UNIQUE(plan_name));";
		const char copySkillPlanTable[] = "INSERT INTO skill_plan_overview SELECT plan_id, plan_name FROM skill_plan_overview_old;";
		const char dropOldPlanOverview[] = "DROP TABLE skill_plan_overview_old;";
		char *error = nil;
		int rc;
		
		rc = sqlite3_exec(db,rename,NULL,NULL,&error);
		if(rc != SQLITE_OK){
			[self logError:error];
			[self rollbackTransaction];
			return NO;
		}
		rc = sqlite3_exec(db,createSkillPlanOverviewTable2,NULL,NULL,&error);
		if(rc != SQLITE_OK){
			[self logError:error];
			[self rollbackTransaction];
			return NO;
		}
		rc = sqlite3_exec(db,copySkillPlanTable,NULL,NULL,&error);
		if(rc != SQLITE_OK){
			[self logError:error];
			[self rollbackTransaction];
			return NO;
		}
		rc = sqlite3_exec(db,dropOldPlanOverview,NULL,NULL,&error);
		if(rc != SQLITE_OK){
			[self logError:error];
			[self rollbackTransaction];
			return NO;
		}
				
		NSLog(@"Succesfully upgraded character database from version 1");
	}
    else if(currentVersion == 2)
    {
		const char rename[] = "ALTER TABLE skill_plan_overview ADD COLUMN plan_order INTEGER AFTER plan_name;";
		char *error = nil;
		int rc;
		
		rc = sqlite3_exec(db,rename,NULL,NULL,&error);
		if(rc != SQLITE_OK){
			[self logError:error];
			[self rollbackTransaction];
			return NO;
		}
        
		NSLog(@"Succesfully upgraded character database from version 2");
    }

    if( toVersion >= 5 )
    {
        char *error = nil;
        int rc;
        
        if( ![self doesTable:@"skill_plan" haveColumn:@"note"] )
        {
            rc = sqlite3_exec(db, "ALTER TABLE skill_plan ADD COLUMN note VARCHAR(1000);", NULL,NULL,&error);
            if(rc != SQLITE_OK){
                [self logError:error];
                [self rollbackTransaction];
                return NO;
            }
        }
        
        if( ![self doesTable:@"skill_plan" haveColumn:@"attribute_set_id"] )
        {
            rc = sqlite3_exec(db, "ALTER TABLE skill_plan ADD COLUMN attribute_set_id INTEGER DEFAULT 0;", NULL,NULL,&error);
            if(rc != SQLITE_OK){
                [self logError:error];
                [self rollbackTransaction];
                return NO;
            }
        }

        NSLog(@"Succesfully upgraded character database table skill_plan");
    }
    
    {
        sqlite3_stmt *update_master;
        const char updateMasterTable[] = "UPDATE master SET version = ? WHERE table_name = 'master';";
        
        int rc = sqlite3_prepare_v2(db,updateMasterTable,(int)sizeof(updateMasterTable),&update_master,NULL);
        if( rc != SQLITE_OK )
        {
            NSLog( @"Failed to prepare master table update" );
            return NO;
        }
        sqlite3_bind_nsint(update_master,1,CURRENT_DB_VERSION);
        if((rc = sqlite3_step(update_master)) != SQLITE_DONE)
        {
            NSLog(@"Error populating master table");
        }
        sqlite3_reset(update_master);
        sqlite3_finalize(update_master);
    }
    
    [self commitTransaction];
    return YES;
}

-(BOOL) checkStatus
{
	char **results;
	char *errormsg;
    const char countMaster[] = "SELECT COUNT(*) FROM master;";
    const char *existenceTest = "SELECT version FROM master;";
	BOOL status = YES;
	int rc;
	int rows;
	int cols;
	long version;
	
    NSInteger count = [self performCount:countMaster];
    if( count > 1 )
        existenceTest = "SELECT version FROM master WHERE table_name = 'master';";
    
	rc = sqlite3_get_table(db, existenceTest, &results, &rows, &cols, &errormsg);
	
	if( (rc != SQLITE_OK) || (rows != 1) )
    {
		NSLog(@"Character Database does not exist");
		return NO;
	}
		
	if(strcmp(results[0],"version") != 0){
		status = NO;
	}
	
	version = strtol(results[1],NULL,10);
	
	if(version != CURRENT_DB_VERSION){
		[self upgradeDatabaseFromVersion:version toVersion:CURRENT_DB_VERSION];
	}
	
	if(results != NULL){
		sqlite3_free_table(results);
	}
	if(errormsg){
		[self logError:errormsg];
	}
	
	return status;
}

-(CharacterDatabase*) initWithPath:(NSString*)dbPath
{
	if(self = (CharacterDatabase*)[super initWithPath:dbPath]){
		[self initDatabase];
	}
	
	return self;
}

-(void) dealloc
{
	[super dealloc];
}

-(BOOL) initDatabase
{
	[self openDatabase];
	
	int rc = [self checkStatus];
	if(!rc){
		rc = [self createDatabase];
		if(!rc){
			NSLog(@"error initialising database database");
			return NO;
		}
	}
	[self closeDatabase];
	
	return rc;
}

-(BOOL) writeSkillPlans:(NSArray*)plans
{
	BOOL rc;
	[self openDatabase];
	[self beginTransaction];
	
	for(SkillPlan *sp in plans){
		if([sp dirty]){
			rc = [self deleteSkillPlanPrivate:sp];
			if(!rc){
				NSLog(@"error deleting skill plan %@",[sp planName]);
				[self rollbackTransaction];
				return NO;
			}
			rc = [self writeSkillPlanPrivate:sp];
			if(!rc){
				NSLog(@"error writing skill plan %@",[sp planName]);
				[self rollbackTransaction];
				return NO;
			}			
		}
	}
	
	rc = [self commitTransaction];
	[self closeDatabase];
	
	if(rc){
		for(SkillPlan *sp in plans){
			[sp setDirty:NO];
		}
	}else{
		NSLog(@"error comming transaction");
	}
	return YES;
}

-(BOOL) deleteAllSkillPlans
{
	[self openDatabase];
	[self beginTransaction];
	BOOL rc = [self deleteAllSkillPlansPrivate];
	[self commitTransaction];
	[self closeDatabase];
	
	return rc;
}

/*delete a single plan*/
-(BOOL) deleteSkillPlan:(SkillPlan*)plan
{
	[self openDatabase];
	[self beginTransaction];
	
	if(![self deleteSkillPlanPrivate:plan]){
		NSLog(@"error deleting plan %@",[plan planName]);
		[self rollbackTransaction];
		return NO;
	}
	
	[self commitTransaction];
	[self closeDatabase];

	return YES;
}

/*write a plan to the database*/
-(BOOL) writeSkillPlan:(SkillPlan*)plan
{
	[self openDatabase];
	[self beginTransaction];
	
	if(![self writeSkillPlanPrivate:plan]){
		NSLog(@"error writing plan %@",[plan planName]);
		[self rollbackTransaction];
		[self closeDatabase];
		return NO;
	}
	
	[self commitTransaction];
	[plan setDirty:NO];
	[self closeDatabase];
	return YES;
}

-(BOOL) readSkillPlan:(SkillPlan*)plan planId:(sqlite_int64)planId
{
	[self openDatabase];
	
	[self readSkillPlanPrivate:plan planId:planId];
	
	[self closeDatabase];
	
	/*
	 remove any skills that have been completed
	 This has the potential to open the database connection, so make sure we close the old one first
	 */
	[plan purgeCompletedSkills];
	
	return YES;
}

/*read in all the skill plans for this character*/
-(NSMutableArray*) readSkillPlans:(Character*)character;
{
	NSMutableArray *skillPlans;
	const char select_skill_plan_overview[] = "SELECT plan_id, plan_name, plan_order FROM skill_plan_overview ORDER BY plan_order;";
	sqlite3_stmt *read_overview_stmt;
	int rc;
	
	[self openDatabase];
	
	rc = sqlite3_prepare_v2(db, select_skill_plan_overview,(int)sizeof(select_skill_plan_overview)
							,&read_overview_stmt, NULL);
	if(rc != SQLITE_OK){
		NSLog(@"sqlite error\n");
		if(read_overview_stmt != NULL){
			sqlite3_finalize(read_overview_stmt);
		}
		[self closeDatabase];
		return nil;
	}
	
	skillPlans = [[[NSMutableArray alloc]init]autorelease];

	while((rc = sqlite3_step(read_overview_stmt)) == SQLITE_ROW){
		sqlite_int64 planId = sqlite3_column_int64(read_overview_stmt,0);
		const unsigned char *planName = sqlite3_column_text(read_overview_stmt,1);
        sqlite_int64 planOrder = sqlite3_column_int64(read_overview_stmt,2);

		SkillPlan *sp = [[SkillPlan alloc]
						 initWithName:[NSString stringWithUTF8String:(const char*)planName]
						 forCharacter:character
						 withId:(NSInteger)planId];
		[sp setPlanOrder:(NSInteger)planOrder];
        
		[self readSkillPlanPrivate:sp planId:planId];
		[skillPlans addObject:sp];
		[sp release];
	}
		
	sqlite3_finalize(read_overview_stmt);
	
	[self closeDatabase];
	
	return skillPlans;
}

- (BOOL) writeOverviewPlanOrder:(NSArray *)plans
{
	BOOL rc;
    sqlite3_stmt *rename_stmt;
    const char rename_plan[] = "UPDATE skill_plan_overview SET plan_order = ? WHERE plan_id = ?;";
    NSInteger ord = 1;
    
	[self openDatabase];
	[self beginTransaction];
	
    rc = sqlite3_prepare_v2(db,rename_plan,(int)sizeof(rename_plan),&rename_stmt,NULL);
	if(rc != SQLITE_OK)
    {
		NSLog(@"sqlite error\n");
		if(rename_stmt != NULL){
			sqlite3_finalize(rename_stmt);
		}
		[self closeDatabase];
		return NO;
	}

	for(SkillPlan *sp in plans)
    {
        sqlite3_bind_nsint(rename_stmt,1,ord++);
        sqlite3_bind_nsint(rename_stmt,2,[sp planId]);
        
        if((rc = sqlite3_step(rename_stmt)) != SQLITE_DONE)
        {
            NSLog(@"Error updating overview plan order");
        }
        
        sqlite3_reset(rename_stmt);
	}
	
    sqlite3_finalize(rename_stmt);
	rc = [self commitTransaction];
	[self closeDatabase];
	
	if(!rc)
    {
		NSLog(@"error comming transaction");
        return NO;
	}
	return YES;
}

-(SkillPlan*) createPlan:(NSString*)planName forCharacter:(Character*)ch
{
	[self openDatabase];
	
	sqlite_int64 planId = [self createSkillPlan:planName];
	
	[self closeDatabase];
	
	if(planId == -1){
		NSLog(@"Duplicate plan name %@",planName);
		return nil;
	}
	
	SkillPlan *sp = [[[SkillPlan alloc]initWithName:planName forCharacter:ch withId:(NSInteger)planId]autorelease];
	
	return sp;
}

-(BOOL) renameSkillPlan:(SkillPlan*)plan
{
	[self openDatabase];
	[self beginTransaction];
	
	BOOL rc = [self renameSkillPlanPrivate:plan];
	
	if(rc){
		[self commitTransaction];
	}else{
		[self rollbackTransaction];
	}
	
	[self closeDatabase];
	
	return rc;
}

@end
