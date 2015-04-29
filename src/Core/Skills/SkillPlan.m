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

#import "GlobalData.h"

#import "SkillTree.h"
#import "SkillPlan.h"
#import "SkillPair.h"

#import "Helpers.h"
#import "Character.h"


@interface SkillPlan (SkillPlanPrivate)
/*
 returns the level if the skill exists in the queue or the characters skill list
 returns zero if the skill does not exist
 */

-(void) addSkillToQueue:(NSNumber*)skill level:(NSInteger)level atFront:(BOOL)front;

-(NSInteger) hasPrerequisiteSkill:(NSNumber*)typeID;
-(NSInteger) hasPrerequisiteSkill:(NSNumber*)typeID beforeIndex:(NSInteger)index inPlan:(NSArray*)plan;

-(NSInteger) hasPrerequisiteSkillQueued:(NSNumber*)typeID beforeIndex:(NSInteger)index inPlan:(NSArray*)plan;

-(void) resetCache;

-(void) removeSkillFromPlan:(SkillPair*)pair;

-(void) insertTrainingSkill;

- (void) updateManualOrder;
- (void) restoreManualOrder;
@end

@implementation SkillPlan (SkillPlanPrivate)

-(void) insertTrainingSkill
{
	/*if the character currently has a skill in training, then insert that at the front of the plan.*/
	if([character integerForKey:CHAR_TRAINING_SKILLTRAINING] == 1)
    {
        [self addSkillToQueue:[NSNumber numberWithInteger:[character integerForKey:CHAR_TRAINING_TYPEID]] level:[character integerForKey:CHAR_TRAINING_LEVEL] atFront:YES];
	}
}

-(void) removeSkillFromPlan:(SkillPair*)pair
{
	[skillPlan removeObject:pair];
    [self updateManualOrder];
}

-(void) resetCache
{
	dirty = YES;
	planTrainingTime = 0;
	[skillDates removeAllObjects];
	[spHrArray removeAllObjects];
}

-(void) addSkillToQueue:(NSNumber*)typeID level:(NSInteger)level atFront:(BOOL)front
{
	SkillPair *sp = [[SkillPair alloc]initWithSkill:typeID level:level];
    
    if( front && ([skillPlan count] != 0) )
    {
        [skillPlan insertObject:sp atIndex:0];
    }
    else
    {
        [skillPlan addObject:sp];
    }
	[sp release];
    [self updateManualOrder];
}

/*
 Helper functions for the recursive skill plan builder.  These check the character or the plan
 to see if the same skill exists at the required level to add the new skill.
 
 these two functions are a bit nasty. optimise this if it starts to get slow
 */
-(NSInteger) hasPrerequisiteSkillQueued:(NSNumber*)typeID beforeIndex:(NSInteger)index inPlan:(NSArray*)plan
{
	NSInteger level = 0;
	NSInteger i = 0;
	for(SkillPair *sp in plan){
		if(i > index){
			return level;
		}
		if([[sp typeID] compare:typeID] == NSOrderedSame){
			if([sp skillLevel] > level){
				level = [sp skillLevel];
			}
		}
		i++;
	}
	return level;
}

-(NSInteger) hasPrerequisiteSkill:(NSNumber*)typeID
{
	return [self hasPrerequisiteSkill:typeID beforeIndex:NSIntegerMax inPlan:skillPlan];
}

-(NSInteger) hasPrerequisiteSkill:(NSNumber*)typeID beforeIndex:(NSInteger)index inPlan:(NSArray*)plan
{
	NSDictionary *charSkillSet = [character skillSet];
	Skill *s = [charSkillSet objectForKey:typeID];
	NSInteger level = 0;
	if(s == nil){
		/*fall back and check the skill plan*/
		level = [self hasPrerequisiteSkillQueued:typeID beforeIndex:index inPlan:plan];
	}else{
		level = [self hasPrerequisiteSkillQueued:typeID beforeIndex:index inPlan:plan];
		if(level > [s skillLevel]){
			return level;
		}else{
			return [s skillLevel];
		}
	}
	
	return level;
}

- (void) updateManualOrder
{
    if( manualOrder )
        [manualOrder release];
    manualOrder = [skillPlan copy];
}

- (void) restoreManualOrder
{
    [skillPlan release];
    skillPlan = [[NSMutableArray alloc] initWithArray:manualOrder];
}

@end


@implementation SkillPlan

@synthesize planName;
@synthesize dirty;
@synthesize planId;
@synthesize planOrder;

-(NSUInteger) hash;
{
	return (NSUInteger)planId;
}

-(BOOL) isEqual:(id)anObject
{
	//if([anObject class]
	return (planId == ((SkillPlan*)anObject)->planId);
}

-(NSString*) description
{
    return [NSString stringWithFormat:@"Skill plan %@\n%@", [self planName], [self EVEText]];
}

-(void) savePlan
{
	[character updateSkillPlan:self];
}


-(void) printPlan
{
	SkillTree *st = [[GlobalData sharedInstance]skillTree];
	NSLog(@"Printing plan");
	for(SkillPair *p in skillPlan){
		NSLog(@"%@ level %ld",[[st skillForId:[p typeID]]skillName], (long)[p skillLevel]);
	}
	NSLog(@"Done printing plan");
}

-(void) dealloc
{
	[skillPlan release];
	[skillDates release];
	[spHrArray release];
	
	[planName release];
    [manualOrder release];
    
	[super dealloc];
}

static NSDictionary *masterSkillSet = nil;;

-(SkillPlan*) init
{
	if(masterSkillSet == nil){
		masterSkillSet = [[[[GlobalData sharedInstance]skillTree] skillSet]retain];
	}
	if(self = [super init]){
		skillPlan = [[NSMutableArray alloc]init];
		skillDates = [[NSMutableArray alloc]init];
		spHrArray = [[NSMutableArray alloc]init];
		dirty = NO;
		planTrainingTime = 0;
		character = nil;
		planName = nil;
	}
	return self;
}

-(SkillPlan*) initWithName:(NSString*)name 
			  forCharacter:(Character*)ch 
					withId:(NSInteger)pId
{
	if(self = [self init]){
		planName = [name retain];
		character = ch; //NOT RETAINED
		planId = pId;
	}
	return self;
}

-(SkillPlan*) initWithName:(NSString*)name character:(Character*)ch
{
	assert(ch);
	assert(name);
	if(self = [self init]){
		planName = [name retain];
		character = ch; //NOT RETAINED.
	}
	return self;
}

/* 
 Recursive function to build up a skill plan for a given skill.
 
 Algorithm:
 
 Check to see if there are any prerequisites.
	If there are
		Add the prerequisite skills to the right level (if not already met).
	End if
 Add the skill
 
 */
-(NSInteger) privateAddSkillToPlan:(NSNumber*)skillID level:(NSInteger)skillLevel
{
	assert(masterSkillSet);
	NSDictionary *charSkillSet = [character skillSet];
	/*skillPlan will be an array of SkillPrerequisite objects*/
	/*check to see if the characer has the skill, and at what level*/
	NSInteger skillsAdded = 0;
	NSInteger currentLevel = [self hasPrerequisiteSkill:skillID];
	
	/*we need to find all of the prerequisite skills for the skillID that has been passed in*/
	Skill *s = [masterSkillSet objectForKey:skillID];
	NSArray *prereqs = [s prerequisites];
	if(prereqs != nil){
		/*there are prerequsites, see that they are met*/
		for(SkillPair *sp in prereqs){
			Skill *charSkill = [charSkillSet objectForKey:[sp typeID]];
			if(charSkill == nil){
				/*skill does not exist. add it*/
				skillsAdded += [self addSkillToPlan:[sp typeID] level:[sp skillLevel]];
			}else if([sp skillLevel] > [charSkill skillLevel]){/*if the required skill level is greater than what we have*/
				/*skill exists. but not at required level.*/
				skillsAdded += [self addSkillToPlan:[sp typeID] level:[sp skillLevel]];
			}
		}
	}
	
	//NSInteger level = [[character skillSet]objectForKey:[skillID]];
	
	/*prerequisites have been satisfied. add skill at level*/
	for(NSInteger i = currentLevel + 1; i <= skillLevel; i++){
		[self addSkillToQueue:skillID level:i atFront:NO];
		//NSLog(@"Added %@ %ld to %@",skillID, skillLevel, planName);
		skillsAdded++;
	}
	return skillsAdded;
}

-(NSInteger) addSkillToPlan:(NSNumber*)skillID level:(NSInteger)skillLevel
{
	NSInteger skillsAdded = [self privateAddSkillToPlan:skillID level:skillLevel];
	if(skillsAdded > 0){
		[self resetCache];
        [self updateManualOrder];
	}
	return skillsAdded;
}

/*supply an array of skillpair objects, in order, to append to the plan.*/
-(void) addSkillArrayToPlan:(NSArray*)prereqArray
{
	NSInteger skillsAdded = 0;
	for(SkillPair *p in prereqArray){
		//NSLog(@"Adding %@ to %@",p,planName);
		skillsAdded += [self privateAddSkillToPlan:[p typeID] level:[p skillLevel]];
	}
	if(skillsAdded > 0){
		[self resetCache];
        [self updateManualOrder];
	}
}


/*for use by the database function that loads the skillplan from the database*/
-(void) secretAddSkillToPlan:(NSNumber*)typeID level:(NSInteger)level
{
	[self addSkillToQueue:typeID level:level atFront:NO];
}


/*
 Iterate over this plan, if the skills are in an order that matches all prerequisites then the plan is valid.
 
 
 Algorithm.
 
 Are the prerequisites for this skill met?
	if no, return NO;
	if yes, continue
 
 return YES.
 */


-(BOOL) validatePlan:(NSArray*)proposedPlan
{
	SkillTree *masterTree = [[GlobalData sharedInstance]skillTree];
	NSInteger i = 0;
	
	for(SkillPair *pair in proposedPlan){
		Skill *s = [masterTree skillForId:[pair typeID]];
		
		NSArray *prerequisites = [s prerequisites];
		
		NSInteger currentLevel = [self hasPrerequisiteSkill:[pair typeID] beforeIndex:i-1 inPlan:proposedPlan];
		
		if(currentLevel < ([pair skillLevel] - 1)){
			return NO;
		}
		
		for(SkillPair *pre in prerequisites){
			NSInteger preCurrentLevel = [self hasPrerequisiteSkill:[pre typeID] beforeIndex:i-1 inPlan:proposedPlan];
			if([pre skillLevel] > preCurrentLevel){
				return NO;
			}
		}
		i++;
	}
	return YES;
}

-(BOOL) validateSkillAtIndex:(NSInteger)index
{
	SkillTree *masterTree = [[GlobalData sharedInstance] skillTree];
	SkillPair *pair = [skillPlan objectAtIndex:index];
    Skill *s = [masterTree skillForId:[pair typeID]];
    
    NSArray *prerequisites = [s prerequisites];
    
    for( SkillPair *pre in prerequisites )
    {
        NSInteger preCurrentLevel = [self hasPrerequisiteSkill:[pre typeID] beforeIndex:index-1 inPlan:skillPlan];
        if( [pre skillLevel] > preCurrentLevel )
        {
            return NO;
        }
    }

	return YES;
}

-(BOOL) privateMoveSkill:(NSArray*)fromIndexArray to:(NSInteger)toIndex
{
	/*returns the skill level of the a prerequisite*/
	NSInteger fromOffset = 0;
	
	NSMutableArray *newPlan = [skillPlan mutableCopy];
	
	NSInteger toOffset = 0;
	for(NSNumber *fromIndex in fromIndexArray){
		SkillPair *skillToMove = [skillPlan objectAtIndex:([fromIndex integerValue] + fromOffset)];
		
		if([newPlan count] == (NSUInteger)(toIndex + toOffset)){
			[newPlan addObject:skillToMove];
			toOffset++;
		}else{
			[newPlan insertObject:skillToMove atIndex:toIndex + toOffset++];
		}
	}
	
	NSInteger removeOffset = 0;
	if(toIndex < ([[fromIndexArray objectAtIndex:0]integerValue] + fromOffset)){
		removeOffset += [fromIndexArray count];
	}
	
	for(NSNumber *fromIndex in fromIndexArray){
		[newPlan removeObjectAtIndex:([fromIndex integerValue] + fromOffset) + removeOffset--];
	}
	
	BOOL rc = [self validatePlan:newPlan];
	
	if(rc){
//		NSLog(@"New plan is OK");
//		NSLog(@"%@",newPlan);
		[skillPlan release];
		skillPlan = newPlan;
		[self resetCache];
        [self updateManualOrder];
	}else{
//		NSLog(@"new plan is invalid");
		[newPlan release];
	}
	
	return rc;
}

/*
 we want to move a skill from fromIndex to toIndex.
 return YES if the skill has been moved (prerequisites have been satisfied)
 return NO if the skill was not moved (prerequisites are not satsified)
*/
-(BOOL) moveSkill:(NSArray*)fromIndexArray to:(NSInteger)toIndex
{
	BOOL rc;
	
	rc = [self privateMoveSkill:fromIndexArray to:toIndex];

	return rc;
}

-(BOOL) removeSkillArrayFromPlan:(NSArray*)prereqArray
{
	[skillPlan removeObjectsInArray:prereqArray];
    [self updateManualOrder];
	[self resetCache];
	return YES;
}

/*
	If a skill is removed from a plan, then everying in the plan that has that skill as a prerequisite
	must also be removed.
	
	therefore, we must calculate what skills in the plan have the supplied skill as a prerequisite.
	
	for a skill, ([skill skillLevel] + 1) is a prerequisite and must be removed
	if any skill has [skill skillLevel] as a prerequisite, it must be removed also.
 
	Capital Ships 1
	Capital Ships 2
	Capital Ships 3
	Capital Ships 4
	Capital Ships 5
	Battleship 5
	Leadership 4
	Leadership 5
	Titan 1
	Titan 2
	Titan 3
	Titan 4
	Titan 5
 
	in the above plan, battleship and leadership are not prerequisites of capital ships, but of titan
 */

// is sp a prerequisite of (typeID,skillLevel) ?
-(BOOL) isPrerequsite:(SkillPair*)sp 
			   ofType:(NSNumber*)typeID 
			  atLevel:(NSInteger)skillLevel 
			 antiPlan:(NSMutableArray*)antiPlan
{
	/*is it already in the antiplan? if so, return.*/
	for(SkillPair *apSp in antiPlan){
		if([[apSp typeID]isEqualToNumber:[sp typeID]]){
			if([apSp skillLevel] == [sp skillLevel]){
				return NO;
			}
		}
	}
	//is SP a prerequisite of type?
	Skill *s = [[[GlobalData sharedInstance]skillTree] skillForId:[sp typeID]]; /*get the prereqs of sp*/
	NSArray *ary = [s prerequisites];
	
	if(ary == nil){
		return NO;
	}
	
	for(SkillPair *pre in ary){
		if([[pre typeID]isEqualToNumber:typeID]){//if typeID is a prerequisite of sp
			if([pre skillLevel] >= skillLevel){
				return YES;
			}
		}
	}
	
	return NO;
}

-(void) constructAntiPlan2:(NSNumber*)typeID 
					 level:(NSInteger)skillLevel 
				  antiPlan:(NSMutableArray*)antiPlan
{
	/*
	 remove any prereq from the plan that matches typeID and has a skillLevel higher than skillLevel
	 remove anything from the plan that depends on typeID at skillLevel
	 */
	
/*	
	Skill *s = [[Config GetInstance]->st skillForId:typeID];
	NSLog(@"Removing %@ at level %ld", [s skillName],skillLevel);
*/	
	for(SkillPair *sp in skillPlan){
		/*does this object require typeID at skillLevel as a prerequisite? if so, remove*/
/*
		NSLog(@"Is (%@,%ld) a prerequisite for (%@,%ld)",
			[[Config GetInstance]->st skillForId:typeID],skillLevel,
			[[Config GetInstance]->st skillForId:[sp typeID]],[sp skillLevel]);
*/
		/*is this the object we are looking for??*/
		if(([[sp typeID]isEqualToNumber:typeID]) && ([sp skillLevel] >= skillLevel)){
			/*base case: we found a prerequisite to remove.*/
			if(![antiPlan containsObject:sp]){
				[antiPlan addObject:sp];
			}
		}
		if([self isPrerequsite:sp ofType:typeID atLevel:skillLevel antiPlan:antiPlan]){
			/*
			 We have found an object to remove. now we must process the tree and remove ANYTHING that requires
			 (sp) as a prerequisite.
			 */
			/*recurse and remove prerequisites of this current skill*/
			[self constructAntiPlan2:[sp typeID] level:[sp skillLevel] antiPlan:antiPlan];
		}
	}
}

/*returns an array of objects that will be removed if the skill at skillIndex will be removed*/
-(NSArray*) constructAntiPlan:(NSInteger)skillIndex
{
	SkillPair *skillToRemove = [skillPlan objectAtIndex:skillIndex];
	NSMutableArray *antiPlan = [[[NSMutableArray alloc]init]autorelease];
	
	[self constructAntiPlan2:[skillToRemove typeID] level:[skillToRemove skillLevel] antiPlan:antiPlan];
	/*
	SkillTree *st = [Config GetInstance]->st;
	NSLog(@"Skills to remove");
	for(SkillPair *sp in antiPlan){
		NSLog(@"%@ %ld",[st skillForId:[sp typeID]], [sp skillLevel]);
	}
	NSLog(@"Done");
	*/
	return antiPlan;
}

/*
 remove multiple indexes from the array. perhaps alter this to take an index set if i use it in any other locations?
 another edge case where the 
 */
-(NSArray*) constructAntiPlan:(NSUInteger*)skillIndex arrayLength:(NSUInteger)arrayLength
{
	NSMutableArray *antiPlan = [[[NSMutableArray alloc]init]autorelease];
		
	for(NSUInteger i = 0; i < arrayLength; i++){
		SkillPair *skillToRemove = [skillPlan objectAtIndex:skillIndex[i]];
		[self constructAntiPlan2:[skillToRemove typeID] level:[skillToRemove skillLevel] antiPlan:antiPlan];
	}
	return antiPlan;
}

/*build up a list of start and finish times for the current plan*/
-(BOOL) buildTrainingTimeList
{
	NSInteger trainingTime = 0;
	SkillPair *pair;
	
	[skillDates removeAllObjects];
	[spHrArray removeAllObjects];
	
	[character resetTempAttrBonus];
	[character processAttributeSkills];
	
	SkillTree *st = [[GlobalData sharedInstance]skillTree];
	
	//Starting date (Now)
	NSDate *date = [[[NSDate alloc]init]autorelease];
	
	NSEnumerator *e = [skillPlan objectEnumerator];	
	while((pair = [e nextObject]) != nil){
		[skillDates addObject:date];		
		
		/*this should take into account amount completed?*/
		trainingTime = [character trainingTimeInSeconds:[pair typeID] fromLevel:[pair skillLevel]-1 toLevel:[pair skillLevel]];
		
		Skill *s = [st skillForId:[pair typeID]];

		NSInteger spPerHour = [character spPerHour:[s primaryAttr] 
										 secondary:[s secondaryAttr]];
		
		[spHrArray addObject:[NSNumber numberWithInteger:spPerHour]];
		
		date = [[[NSDate alloc]initWithTimeInterval:trainingTime sinceDate:date]autorelease];
		[skillDates addObject:date];
	}
	
	//Reset the character attributes, as the character may have been modified
	[character resetTempAttrBonus];
	[character processAttributeSkills];
	return YES;
}

-(NSInteger) purgeCompletedSkills
{
	SkillTree *st = [character skillTree];
	NSMutableIndexSet *index = [[NSMutableIndexSet alloc]init];
	
	NSInteger i = 0;
	for(SkillPair *pair in skillPlan){
		Skill *s = [st skillForId:[pair typeID]];
		if(s != nil){
			if([s skillLevel] >= [pair skillLevel]){
				/*remove this skill from the array*/
				[index addIndex:i];
			}
		}
		i++;
	}
	if((i = [index count]) > 0){
		[skillPlan removeObjectsAtIndexes:index];
		NSLog(@"remove %ld completed skills from plan", (unsigned long)[index count]);
		[self savePlan];
        [self updateManualOrder];
	}
	
	[index release];
	
	return i;
}

/*returns a start and finish date the indexed skill*/
-(NSDate*) skillTrainingStart:(NSInteger)skillIndex
{
	if([skillDates count] == 0){
		[self buildTrainingTimeList];
	}
	
	if((NSUInteger)skillIndex >= [skillPlan count]){
		NSLog(@"Error: %ld is out of bounds (%ld)", (long)skillIndex, (unsigned long)[skillPlan count]);
	}
	
	return [skillDates objectAtIndex:skillIndex * 2];
}

-(NSDate*) skillTrainingFinish:(NSInteger)skillIndex
{
	if([skillDates count] == 0){
		[self buildTrainingTimeList];
	}
	
	if((NSUInteger)skillIndex >= [skillPlan count]){
		NSLog(@"Error: %ld is out of bounds (%ld)", (long)skillIndex, (unsigned long)[skillPlan count]);
	}
	
	return [skillDates objectAtIndex:(skillIndex*2)+1];
}

-(NSDate*) planFinishDate
{
	return [self skillTrainingFinish:[skillPlan count]-1];
}

-(NSInteger) trainingTime:(BOOL)recalc
{
	if(recalc){
		[self resetCache];
	}
	return [self trainingTime];
}

-(NSInteger) trainingTime
{
	if(planTrainingTime != 0){
		return planTrainingTime;
	}
	
	if([skillPlan count] == 0){
		return 0;
	}
	
	planTrainingTime = (NSInteger)[[self skillTrainingFinish:[self skillCount]-1]timeIntervalSinceDate:[self skillTrainingStart:0]];
	
	return planTrainingTime;
}


-(NSInteger) trainingTimeFromDate:(NSDate*)now
{	
	if([skillPlan count] == 0){
		return 0;
	}
	
	NSInteger time = (NSInteger) [[self skillTrainingFinish:[self skillCount]-1]timeIntervalSinceDate:now];
	
	return MAX(time,0);
}

-(NSInteger) trainingTimeOfSkillAtIndex:(NSInteger)skillIndex fromDate:(NSDate*)now
{
	if([skillPlan count] == 0){
		return 0;
	}
	
	NSInteger time = (NSInteger) [[self skillTrainingFinish:skillIndex]timeIntervalSinceDate:now];
	
	return MAX(time,0);
}


-(NSInteger) skillCount
{
	return [skillPlan count];
}

-(SkillPair*) skillAtIndex:(NSInteger)index
{
	return [skillPlan objectAtIndex:index]; 
}

-(NSInteger) maxLevelForSkill:(NSNumber*)typeId atIndex:(NSInteger*)index;
{
	NSInteger level = 0;
	NSInteger i = 0;
	
	for(SkillPair *pair in skillPlan){
		if([[pair typeID]isEqualToNumber:typeId]){
			if([pair skillLevel] > level){
				level = [pair skillLevel];
				if(index != NULL){
					*index = i;
				}
			}
		}
		i++;
	}
	return level;
}

-(NSNumber*) spHrForSkill:(NSInteger)index
{
	if([spHrArray count] == 0){
		return nil;
	}
	return [spHrArray objectAtIndex:index];
}

-(BOOL) increaseSkillToLevel:(SkillPair*)pair
{
	NSInteger curIndex;
	NSInteger curMaxLevel = [self maxLevelForSkill:[pair typeID] atIndex:&curIndex];
	NSInteger increaseToLevel = [pair skillLevel];
	
	if(curMaxLevel == 0){
		return NO;
	}
	
	NSMutableArray *newPlan = [skillPlan mutableCopy];
	
	curIndex++; //Current index where we are inserting.  move to one beyond the skill.
	
	for(NSInteger i = curMaxLevel + 1; i <= increaseToLevel; i++){
		
		SkillPair *newPair = [[SkillPair alloc]initWithSkill:[pair typeID] level:i];
		
		if(curIndex >= [newPlan count]){
			[newPlan addObject:newPair];
		}else{
			[newPlan insertObject:newPair atIndex:curIndex];
		}
		
		[newPair release];
		curIndex++;
	}
	
	if([self validatePlan:newPlan]){
		[skillPlan release];
		skillPlan = newPlan;
		[self resetCache];
		[self savePlan];
        [self updateManualOrder];
		return YES;
	}else{
		[newPlan release];
		return NO;
	}
	
}

-(BOOL) addSkill:(SkillPair*)pair atIndex:(NSInteger)index
{	
	NSMutableArray *newPlan = [skillPlan mutableCopy];
	
	if(index >= [newPlan count]){
		[newPlan addObject:pair];
	}else{
		[newPlan insertObject:pair atIndex:index];
	}
	
	if([self validatePlan:newPlan]){
		[skillPlan release];
		skillPlan = newPlan;
		[self resetCache];
		[self savePlan];
        [self updateManualOrder];
		return YES;
	}else{
		[newPlan release];
		return NO;
	}
	
	return NO;
}

-(void) removeSkillAtIndex:(NSInteger)index
{
	NSArray *ary = [self constructAntiPlan:index];
	
	[self removeSkillArrayFromPlan:ary];
}

-(NSInteger)indexOfSkill:(NSNumber *)typeID level:(NSInteger)level
{
    for( int i = 0; i < [skillPlan count]; i++ )
    {
//        if( [pair isEqualToSkillPair:[skillPlan objectAtIndex:i]] )
        SkillPair *test = [skillPlan objectAtIndex:i];
        if( [typeID isEqualToNumber:[test typeID]]
           && (level == [test skillLevel]) )
        {
            return i;
        }
    }
    return NSNotFound;
}

// start at the top of the plan
// if current skill has any pre-requisite that's lower in the plan
// then move current skill below that pre-requisite
-(void) sortPlanByPrerequisites
{
	SkillTree *masterTree = [[GlobalData sharedInstance] skillTree];
    NSDictionary *charSkillSet = [character skillSet];
	NSInteger i = 0;
	
	while( i < ([skillPlan count] - 1) )
    {
        SkillPair *pair = [skillPlan objectAtIndex:i];
		Skill *currentSkill = [masterTree skillForId:[pair typeID]];
						
		for( SkillPair *pre in [currentSkill prerequisites] )
        {
            Skill *s = [charSkillSet objectForKey:[pre typeID]];
            if( [s skillLevel] >= [pre skillLevel] )
                continue;

            NSInteger preIndex = [self indexOfSkill:[pre typeID] level:[pre skillLevel]];
            if( (NSNotFound != preIndex) && (preIndex > i) )
            {
                // pre-requisite is farther down the plan than the current skill. So move this skill after the pre-req.
                [pair retain];
                if( preIndex >= [skillPlan count] )
                    [skillPlan addObject:pair];
                else
                    [skillPlan insertObject:pair atIndex:preIndex+1];
                [skillPlan removeObjectAtIndex:i];
                [pair release];
                --i; // back up to make sure the skill we just swapped into i doesn't have any pre-requisites
                break;
            }
		}
		i++;
	}
    
    // still have to make sure that levels within a skill are in the right order
    i = 0;
    while( i < ([skillPlan count] - 1) )
    {
        SkillPair *pair = [skillPlan objectAtIndex:i];
        if( [pair skillLevel] > 1 )
        {
            NSInteger preIndex = [self indexOfSkill:[pair typeID] level:([pair skillLevel]-1)];
            if( (NSNotFound != preIndex) && (preIndex > i) )
            {
                // Previous level of this skill is farther down the plan than the current skill. So move this skill after the pre-req.
                [pair retain];
                if( preIndex >= [skillPlan count] )
                    [skillPlan addObject:pair];
                else
                    [skillPlan insertObject:pair atIndex:preIndex+1];
                [skillPlan removeObjectAtIndex:i];
                [pair release];
                --i;
            }
        }
        i++;
    }
    
    [self updateManualOrder];
    [self savePlan];
}

- (void)sortUsingDescriptors:(NSArray *)sortDescriptors
{
    for( NSSortDescriptor *desc in [sortDescriptors reverseObjectEnumerator] )
    {
        if( [[desc key] isEqualToString:@"trainingTime"] )
        {
            [skillPlan sortUsingComparator:^(id obj1, id obj2) {
                NSInteger t1 = [character trainingTimeInSeconds:[obj1 typeID] fromLevel:[obj1 skillLevel]-1 toLevel:[obj1 skillLevel]];
                NSInteger t2 = [character trainingTimeInSeconds:[obj2 typeID] fromLevel:[obj2 skillLevel]-1 toLevel:[obj2 skillLevel]];
                
                if( t1 < t2 )
                    return [desc ascending]?NSOrderedAscending:NSOrderedDescending;
                else if( t2 < t1 )
                    return [desc ascending]?NSOrderedDescending:NSOrderedAscending;
                else
                    return NSOrderedSame;
            }];
        }
        else if( [[desc key] isEqualToString:@"name"] )
        {
            [skillPlan sortUsingDescriptors:[NSArray arrayWithObject:desc]];
        }
        else if( [[desc key] isEqualToString:@"primary"] || [[desc key] isEqualToString:@"secondary"])
        {
            [skillPlan sortUsingComparator:^(id obj1, id obj2) {
                Skill *s1 = [masterSkillSet objectForKey:[obj1 typeID]];
                Skill *s2 = [masterSkillSet objectForKey:[obj2 typeID]];
                NSString *attr1 = [s1 valueForKey:[desc key]];
                NSString *attr2 = [s2 valueForKey:[desc key]];
                
                NSComparisonResult res = [attr1 compare:attr2];
                if( NSOrderedSame == res )
                    return res;
                if( [desc ascending] )
                    return res;
                if( NSOrderedAscending == res )
                    return NSOrderedDescending;
                else
                    return NSOrderedAscending;
            }];
        }
        else if( [[desc key] isEqualToString:@"percent"] )
        {
            [skillPlan sortUsingComparator:^(id obj1, id obj2) {
                CGFloat percent1 = [character percentCompleted:[obj1 typeID]
                                                     fromLevel:[obj1 skillLevel]-1
                                                       toLevel:[obj1 skillLevel]];
                CGFloat percent2 = [character percentCompleted:[obj2 typeID]
                                                     fromLevel:[obj2 skillLevel]-1
                                                       toLevel:[obj2 skillLevel]];
                
                if( percent1 < percent2 )
                    return [desc ascending]?NSOrderedAscending:NSOrderedDescending;
                else if( percent2 < percent1 )
                    return [desc ascending]?NSOrderedDescending:NSOrderedAscending;
                else
                    return NSOrderedSame;
            }];
        }
        else if( [[desc key] isEqualToString:@"spPerHour"] )
        {
            [skillPlan sortUsingComparator:^(id obj1, id obj2) {
                Skill *s1 = [masterSkillSet objectForKey:[obj1 typeID]];
                Skill *s2 = [masterSkillSet objectForKey:[obj2 typeID]];
                NSInteger spPerHour1 = [character spPerHour:[s1 primaryAttr]
                                                  secondary:[s1 secondaryAttr]];
                NSInteger spPerHour2 = [character spPerHour:[s2 primaryAttr]
                                                  secondary:[s2 secondaryAttr]];

                if( spPerHour1 < spPerHour2 )
                    return [desc ascending]?NSOrderedAscending:NSOrderedDescending;
                else if( spPerHour2 < spPerHour1 )
                    return [desc ascending]?NSOrderedDescending:NSOrderedAscending;
                else
                    return NSOrderedSame;
            }];
        }
    }

    if( 0 == [sortDescriptors count] )
    {
        [self restoreManualOrder];
    }
    
    [self resetCache];
}

-(NSString *)EVEText
{
    NSMutableString *planString = [NSMutableString string];
    
    for( SkillPair *sp in skillPlan )
    {
        [planString appendFormat:@"%@\n", [sp roman]];
    }
    
    return planString;
}
@end
