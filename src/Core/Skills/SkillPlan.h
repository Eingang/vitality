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

#import "SkillPair.h"
#import "SkillPlanNote.h"

//Some of the comments in this file may or may not be a bit out of date


/*
	the skillPlan array is an array of SkillPrerequisite objects.
	
	the array must always be in the correct prerequsite order, so that the skill plan can be 
	trained from beginning to end
*/
@class Character;

@interface SkillPlan : NSObject {
	/*the array of objects in the skill plan*/
	NSMutableArray *skillPlan;
	/*the start and finish dates of each skill in the plan, use accesor methods to get the dates*/
	NSMutableArray *skillDates;

    /*this should be kept somewhere else*/
	Character *character; //the character that created this object. NOT RETAINED.
	
	NSString *planName;
	NSInteger planTrainingTime;
	NSInteger planId;
    NSInteger planOrder;
	BOOL dirty;
    
    NSArray *manualOrder; ///< A copy of the skillPlan with the skills in the original, un-sorted order
}

@property (readwrite,retain,nonatomic) NSString* planName;
@property (readwrite,nonatomic) BOOL dirty;
@property (readonly,nonatomic) NSInteger planId;
@property (readwrite,nonatomic) NSInteger planOrder;

/*name of the plan, and the skillset that the character has.*/

// deprecated. don't use anymore
-(SkillPlan*) initWithName:(NSString*)name 
				 character:(Character*)ch;


/*
	create a skill plan through the character object, don't
	call this directly
 */
-(SkillPlan*) initWithName:(NSString*)name 
			  forCharacter:(Character*)ch 
					withId:(NSInteger)pId;


/* 
 If the skill can be added, it and any prerequisites will be added in the required order.
 
 Returns the number of skills added
 */
-(NSInteger) addSkillToPlan:(NSNumber*)skillID level:(NSInteger)skillLevel;

/*add suppy an array of SkillPrerequisite* objects*/
-(void) addSkillArrayToPlan:(NSArray*)prereqArray;

/*
 remove skills from the plan. must not break the prerequisite requirements of the plan.
 generate array using constructAntiPlan
 */
-(BOOL) removeSkillArrayFromPlan:(NSArray*)prereqArray;

/*number of skills in the plan*/
-(NSInteger) skillCount;
-(SkillPair*) skillAtIndex:(NSInteger)index;
/*returns the max level this skill is queued to*/
-(NSInteger) maxLevelForSkill:(NSNumber*)typeId atIndex:(NSInteger*)index;

/*supply an array of indexes of skills you want to move, and the location where you want them all inserted*/
-(BOOL) moveSkill:(NSArray*)fromIndexArray to:(NSInteger)toIndex;

/*
 insert a skill at the given index.
 Prerequisites must be satisfied for this to work.
 TRUE on success. FALSE on failure.
 */
-(BOOL) addSkill:(SkillPair*)pair atIndex:(NSInteger)index;

/*take an already queued skill that is less than level, and increase it to level*/
-(BOOL) increaseSkillToLevel:(SkillPair*)pair;

-(void) removeSkillAtIndex:(NSInteger)index;

-(BOOL) addNote:(NSString *)note atIndex:(NSInteger)index;

/*returns the total training time of the plan in seconds*/
-(NSInteger) trainingTime;
-(NSInteger) trainingTime:(BOOL)recalc;

/*returns how long it will take to train the queue, from the given start date*/
-(NSInteger) trainingTimeFromDate:(NSDate*)now;
/*returns how long it will take to train the skill at the index, starting from the given start date*/
-(NSInteger) trainingTimeOfSkillAtIndex:(NSInteger)skillIndex fromDate:(NSDate*)now;

/*should be obvious*/
-(void) savePlan;

/*remove the skill at skillIndex, returns an array of skills to be removed.*/
-(NSArray*) constructAntiPlan:(NSInteger)skillIndex;
-(NSArray*) constructAntiPlanWithIndexes:(NSIndexSet *)indexes;

/*returns a start and finish date the indexed skill*/
-(NSDate*) skillTrainingStart:(NSInteger)skillIndex;
-(NSDate*) skillTrainingFinish:(NSInteger)skillIndex;

-(NSDate*) planFinishDate;

-(NSInteger) purgeCompletedSkills;

/*used by the database backend to load up skill plans, does not perform validation*/
-(void) secretAddSkillToPlan:(NSNumber*)typeID level:(NSInteger)level;

- (void)sortUsingDescriptors:(NSArray *)sortDescriptors;

-(BOOL) validateSkillAtIndex:(NSInteger)index;

/* Do the minimal amount of sorting needed to make sure that all skills are after their pre-requisites */
-(void) sortPlanByPrerequisites;


-(NSString *)descriptionPlainText; ///< The skill plan as a simple list of "<skill> <level>" entries, for use pasting into the EVE client
-(NSString *)descriptionInGame; ///< E.g. "<a href='showinfo:884791'>Jump Drive Operation</a>	 L5"
@end
