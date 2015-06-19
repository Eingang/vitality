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

#import "SkillDetailsWindowController.h"
#import "GlobalData.h"
#import "Character.h"
#import "Skill.h"
#import "Helpers.h"
#import "macros.h"
#import "SkillPair.h"

#import "SkillDetailsTrainingTimeDatasource.h"
#import "SkillDetailsPointsDatasource.h"
#import "SkillPrerequisiteDatasource.h"
#import "SkillEnablesTypeDatasource.h"

@implementation SkillDetailsWindowController

-(void) awakeFromNib
{
	[skillPrerequisites setIndentationMarkerFollowsCell:YES];
}

-(void) setSkill:(Skill*)s forCharacter:(Character*)c
{
	[self doesNotRecognizeSelector:_cmd];
}


-(id) initWithSkill:(Skill*)sk forCharacter:(Character*)ch
{
	if(self = [super initWithWindowNibName:@"SkillDetails"]){
		skill = [sk retain];
		character = [ch retain];
	}
	return self;
}

+(void) displayWindowForSkill:(Skill*)s forCharacter:(Character*)c
{
    // Suppress the clang analyzer warning. There's probably a better way to do this
#ifndef __clang_analyzer__
	SkillDetailsWindowController *wc = [[SkillDetailsWindowController alloc]
										 initWithSkill:s forCharacter:c];
    
    [[wc window]makeKeyAndOrderFront:nil];
#endif
}

+(void) displayWindowForTypeID:(NSNumber*)tID forCharacter:(Character*)c
{
	Skill *s;
	
	s = [[c skillTree] skillForId:tID];
	if(s == nil){
		s = [[[GlobalData sharedInstance]skillTree] skillForId:tID];
	}		
	
	[SkillDetailsWindowController displayWindowForSkill:s forCharacter:c];
}

-(id) init
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

-(void) dealloc
{
	[skillPrerequisites setDataSource:nil];
	[skillPoints setDataSource:nil];
	[skillTrainingTimes setDataSource:nil];
	[skillEnables setDataSource:nil];
	
	[skillPointsDs release];
	[skillEnableDs release];
	[skillTrainDs release];
	[skillPreDs release];
	
	[skill release];
	[character release];
	[super dealloc];
}


-(void) setLabels
{
	[skillName setStringValue:[skill skillName]];
	[skillName sizeToFit];
	
	[skillRank setIntegerValue:[skill skillRank]];
	[skillRank sizeToFit];
	
	[skillGroup setStringValue:[[[[GlobalData sharedInstance]skillTree] groupForId:[skill groupID]]groupName]];
	[skillGroup sizeToFit];
	
	[skillPrimaryAttr setStringValue:strForAttrCode([skill primaryAttr])];
	[skillPrimaryAttr sizeToFit];
	
	[skillSecondaryAttr setStringValue:strForAttrCode([skill secondaryAttr])];
	[skillSecondaryAttr sizeToFit];
	
	[pilotLevel setIntegerValue:[skill skillLevel]];
	[pilotLevel sizeToFit];
	
	[pilotPoints setIntegerValue:[skill skillPoints]];
	[pilotPoints sizeToFit];
	
	[pilotTimeToLevel setStringValue:
	 stringTrainingTime(
			[character trainingTimeInSeconds:[skill typeID] fromLevel:[skill skillLevel] toLevel:[skill skillLevel]+1]
						)];
	[pilotTimeToLevel sizeToFit];
	
	[pilotTrainingRate setStringValue:
			[NSString stringWithFormat:@"%ld SP/hr",
			(long)[character spPerHour:[skill primaryAttr]
				   secondary:[skill secondaryAttr]]]];
	[pilotTrainingRate sizeToFit];
	
    // Some skills contain html and should be converted to attributed strings before display
    // E.g. Advanced skill at using Jump Drives. Each skill level grants a 20% increase in maximum jump range.
    //      <font color="0xffF67828"><b>This skill cannot be trained on Trial Accounts.</b></font>
    NSString *tempDesc = [[skill skillDescription] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br />\n"];
    NSAttributedString *display = [[[NSAttributedString alloc] initWithHTML:[tempDesc dataUsingEncoding:NSUTF8StringEncoding] options:nil documentAttributes:nil] autorelease];
	[skillDescription setAttributedStringValue:display];
	
	[skillPrerequisites setDelegate:self];
	[skillPoints setDelegate:self];
	[skillTrainingTimes setDelegate:self];
}

-(void) setDatasource
{

	skillPreDs = [[SkillPrerequisiteDatasource alloc]initWithSkill:[NSArray arrayWithObject:skill] 
													  forCharacter:character];
	[skillPrerequisites setDataSource:skillPreDs];
	
	skillTrainDs = [[SkillDetailsTrainingTimeDatasource alloc]initWithSkill:skill forCharacter:character];
	[skillTrainingTimes setDataSource:skillTrainDs];

	skillPointsDs = [[SkillDetailsPointsDatasource alloc]initWithSkill:skill];
	[skillPoints setDataSource:skillPointsDs];
	
	skillEnableDs = [[SkillEnablesTypeDatasource alloc]initWithSkillID:[[skill typeID]integerValue] 
														  forCharacter:character];
	[skillEnables setDataSource:skillEnableDs];
}

-(void) windowDidLoad
{
	if(character == nil){
		return;
	}
	if(skill == nil){
		return;
	}
	
	[self setLabels];
	[self setDatasource];
	
	[[self window]setTitle:[NSString stringWithFormat:@"%@ - %@",[[self window]title],[skill skillName]]];
	
	[skillPrerequisites expandItem:nil expandChildren:YES];
	
	[[NSNotificationCenter defaultCenter] 
		addObserver:self
		selector:@selector(windowWillClose:)
		name:NSWindowWillCloseNotification
		object:[self window]];
	
}

/*delegate methods to prevent editing*/
- (BOOL)tableView:(NSTableView *)aTableView 
shouldEditTableColumn:(NSTableColumn *)aTableColumn 
			  row:(NSInteger)rowIndex
{
	return NO;
}
- (BOOL)outlineView:(NSOutlineView *)outlineView 
shouldEditTableColumn:(NSTableColumn *)tableColumn 
			   item:(id)item
{
	return NO;
}

-(void) windowWillClose:(NSNotification*)note
{
	[[NSNotificationCenter defaultCenter]removeObserver:self];
	[self autorelease];
}

@end
