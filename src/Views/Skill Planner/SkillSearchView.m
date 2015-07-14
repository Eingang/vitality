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
#import <AppKit/NSOutlineView.h>

#import "SkillSearchView.h"
#import "Config.h"
#import "SkillDetailsWindowController.h"
#import "ShipDetailsWindowController.h"
#import "CertDetailsWindowController.h"
#import "ModuleDetailsWindowController.h"
#import "SkillPair.h"

#import "Cert.h"
#import "CCPType.h"
#import "CCPGroup.h"

@interface SkillSearchView (SkillSearchViewPrivate)

-(void) addSearchType:(id<SkillSearchDatasource>)data;

/*this will be called with a search string the user wants to search for.*/
-(void) skillSearchFilter:(id)sender;

@end


@implementation SkillSearchView (SkillSearchViewPrivate)

-(void) addSearchType:(id<SkillSearchDatasource>)data
{
	NSInteger segmentCount = [skillSearchCategories segmentCount];
	
	if(segmentCount == 1){
		if([[skillSearchCategories cell] tagForSegment:segmentCount-1] == 99){
			/*special case cos apple is retarded*/
			[skillSearchCategories setLabel:[data skillSearchName] forSegment:segmentCount-1];
			[[skillSearchCategories cell] setTag:segmentCount-1 forSegment:segmentCount-1];
			[datasources addObject:data];
			[skillSearchCategories sizeToFit];
			currentDatasource = 0;
			return;
		}
	}
	
	[skillSearchCategories setSegmentCount:segmentCount+1];
	[skillSearchCategories setLabel:[data skillSearchName] forSegment:segmentCount];
	[[skillSearchCategories cell]setTag:segmentCount forSegment:segmentCount];
	[skillSearchCategories sizeToFit];
	[datasources addObject:data];
}

-(void) skillSearchFilter:(id)sender
{
	[[datasources objectAtIndex:currentDatasource]skillSearchFilter:sender];
	[skillList reloadData];
}

@end



@implementation SkillSearchView



-(SkillSearchView*) initWithFrame:(NSRect)rect
{
	if(self = [super initWithFrame:rect]){
		datasources = [[NSMutableArray alloc]init];
		[skillSearchCategories setSegmentCount:0];
	}
	
	return self;
}

-(void) dealloc
{
	[datasources release];
	[super dealloc];
}



-(void) planViewAction:(id)sender
{
	NSLog(@"action %@",sender);
}

-(void) awakeFromNib
{
    [[self window] setInitialFirstResponder:search];
    
	//NSLog(@"%@ awakeFromNib",[self className]);
	[skillList setDelegate:self];
	
	[skillList setTarget:self];
	[skillList setDoubleAction:@selector(planViewDoubleClick:)];
	[skillList setAction:@selector(skillTreeSingleClick:)];
	
	[skillList setIndentationMarkerFollowsCell:YES];
	
	[search setAction:@selector(skillSearchFilter:)];
	[search setTarget:self];
	[[search cell]setSendsSearchStringImmediately:YES];
	
}

-(id<SkillSearchDelegate>) delegate
{
	return delegate;
}

-(void) setDelegate:(id<SkillSearchDelegate>)del;
{
	delegate = del;
}


-(void) addDatasource:(id<SkillSearchDatasource>)anObject;
{
    if( anObject )
        [self addSearchType:anObject];
}

-(void) removeDatasources
{
	[skillList setDataSource:nil];
	[datasources removeAllObjects];
	[skillSearchCategories setSegmentCount:0];
}

- (NSSearchField *)searchField
{
    return search;
}

-(IBAction) skillSearchCategoriesClick:(id)sender
{
	NSInteger tag = [[sender cell] tagForSegment:[sender selectedSegment]];
    if( tag != currentDatasource )
    {
        // first clear the current search since it's not likely to make sense for a different tab
        id<SkillSearchDatasource,NSOutlineViewDataSource> oldData = [datasources objectAtIndex:currentDatasource];
        [search setStringValue:@""];
        [oldData skillSearchFilter:search];
        
        id<SkillSearchDatasource,NSOutlineViewDataSource> data = [datasources objectAtIndex:tag];
        [skillList setDataSource:data];
        currentDatasource = tag;
    }
}

-(IBAction) skillGroupsClick:(id)sender
{
	
}

-(void) reloadDatasource:(id<SkillSearchDatasource>)ds
{
	id data = [skillList dataSource];
	if(data == ds){
		[skillList reloadData];
	}
	
//	[skillList collapseItem:nil collapseChildren:YES];
//	[skillList reloadItem:nil reloadChildren:YES];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView 
shouldEditTableColumn:(NSTableColumn *)tableColumn 
			   item:(id)item
{
	return NO;
}

/*called when the user wants to add a skill to a certian level*/
-(void) menuAddSkillClick:(id)sender
{
	id object = [sender representedObject];
	if([object isKindOfClass:[NSArray class]]){
		[delegate planAddSkillArray:object];
	}else{
		[delegate planAddSkillArray:[NSArray arrayWithObject:object]];
	}
}

-(void) selectDefaultGroup
{
	[skillSearchCategories setSelectedSegment:0];
	NSInteger tag = [[skillSearchCategories cell] tagForSegment:[skillSearchCategories selectedSegment]];
    id<SkillSearchDatasource,NSOutlineViewDataSource> data = [datasources objectAtIndex:tag];
    [skillList setDataSource:data];
    currentDatasource = tag;

//	[self skillSearchCategoriesClick:skillSearchCategories];
}

/*pop up the skill window*/
-(void) displayItemAtRow:(NSInteger)row {
	id item = [skillList itemAtRow:row];
	
	if ([item isKindOfClass:[Skill class]]) {
        [SkillDetailsWindowController displayWindowForTypeID: [(Skill*) item typeID] forCharacter:[delegate character]];
	} else if([item isKindOfClass:[CCPType class]]) {
        CCPType *type = item;
        
        // need to find the group's category. categoryID == 6 is ships
        if( [[type group] categoryID] == DB_CATEGORY_SHIP )
        {
            [ShipDetailsWindowController displayShip:item forCharacter:[delegate character]];
        } else {
            [ModuleDetailsWindowController displayModule:item forCharacter:[delegate character]];
        }
	} else if([item isKindOfClass:[Cert class]]) {
		[CertDetailsWindowController displayWindowForCert:item character:[delegate character]];
	}
}

-(void) displaySkillWindow:(id)sender
{
	id item = [sender representedObject];
	NSInteger row = [skillList rowForItem:item];
	
	if(row == -1){
		return;
	}
	
	[self displayItemAtRow:row];
}

-(void) displayShipWindow:(id)sender
{
	[ShipDetailsWindowController displayShip:[sender representedObject] forCharacter:[delegate character]];
}

-(void) displayCertWindow:(id)sender
{
	[CertDetailsWindowController displayWindowForCert:[sender representedObject]
											character:[delegate character]];
}

-(void) planViewDoubleClick:(id)sender
{
	NSInteger row = [skillList selectedRow];
	if(row == -1){
		return;
	}
	
	[self displayItemAtRow:row];
}



-(void) skillTreeSingleClick:(id)sender
{
	NSPoint mouse = [[sender window] convertScreenToBase:[NSEvent mouseLocation]];
	mouse = [sender convertPoint:mouse fromView:nil];
	NSInteger row = [sender rowAtPoint:mouse];
	if(row == -1){
		return;
	}
	id item = [sender itemAtRow:row];
	if([sender isItemExpanded:item]){
		[sender collapseItem:item];
	}else{
		[sender expandItem:item];
	}
}

/*
	display a tooltip
	Forward this on to the datasource.
 */
- (NSString *)outlineView:(NSOutlineView *)ov 
		   toolTipForCell:(NSCell *)cell 
					 rect:(NSRectPointer)rect 
			  tableColumn:(NSTableColumn *)tc 
					 item:(id)item 
			mouseLocation:(NSPoint)mouseLocation
{
    id ds = [skillList dataSource];
    if( [ds respondsToSelector:@selector(outlineView:toolTipForCell:rect:tableColumn:item:mouseLocation:)] )
    {
        return [ds outlineView:ov
                toolTipForCell:cell
                          rect:rect
                   tableColumn:tc
                          item:item
                 mouseLocation:mouseLocation];
    }
    return nil;
}


@end
