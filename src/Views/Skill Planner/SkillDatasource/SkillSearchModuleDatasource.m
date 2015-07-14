#import "SkillSearchModuleDatasource.h"

#import "GlobalData.h"
#import "CCPDatabase.h"
#import "CCPType.h"
#import "CCPCategory.h"
#import "CCPGroup.h"
#import "METSubGroup.h"

#import "Config.h"

#import "macros.h"

@implementation SkillSearchModuleDatasource

@synthesize displayName = _displayName;

-(id)init
{
	if(self = [super init])
    {
		searchObjects = [[NSMutableArray alloc] init];
        _displayName = @"Item";
	}
	return self;
}

-(void) dealloc
{
	[database release];
	[category release];
	[searchObjects release];
	[searchString release];
    [_displayName release];
	[super dealloc];
}

-(id)initWithCategory:(NSInteger)cat
{
	if( self = [self init] )
    {
        database = [[[GlobalData sharedInstance] database] retain];
		if(database == nil)
        {
			[self autorelease];
			return nil;
		}
		
		category = [[database category:cat] retain];
	}
	return self;
}

-(NSString*) skillSearchName
{
	return NSLocalizedString( [self displayName], @"Modules for skill planner." );
}

-(void) skillSearchFilter:(id)sender
{
	NSString *searchValue = [[sender cell]stringValue];
	
	if([searchValue length] == 0){
		[searchString release];
		searchString = nil;
		[searchObjects removeAllObjects];
		return;
	}
	
	[searchObjects removeAllObjects];
	[searchString release];
	searchString = [searchValue retain];
	
	/*this will need to be an array of typeobjects. jesus.*/
	
	NSInteger groupCount = [category groupCount];
	
	for(NSInteger i = 0; i < groupCount; i++){
		CCPGroup *group = [category groupAtIndex:i];
		NSInteger typeCount = [group typeCount];
		for(NSInteger j = 0; j < typeCount; j++){
			CCPType *type = [group typeAtIndex:j];
			NSRange r = [[type typeName]rangeOfString:searchString options:NSCaseInsensitiveSearch];
			if(r.location != NSNotFound){
				[searchObjects addObject:type];
			}
		}
	}
}

-(NSInteger) outlineView:(NSOutlineView*)outlineView numberOfChildrenOfItem:(id)item
{
	if(item == nil){
		if([searchObjects count] > 0){
			return [searchObjects count];
		}
		return [category groupCount];
	}
	
	if([item isKindOfClass:[CCPGroup class]]){
		return [item typeCount];
	}
	
	return 0;
}

-(id) outlineView:(NSOutlineView*)outlineView child:(NSInteger)index ofItem:(id)item
{
	if(item == nil){
		if([searchObjects count] > 0){
			return [searchObjects objectAtIndex:index];
		}
		return [category groupAtIndex:index];
	}
    
	if([item isKindOfClass:[CCPGroup class]]){
		return [item typeAtIndex:index];
	}

	return nil;
}

-(BOOL) outlineView:(NSOutlineView*)outlineView isItemExpandable:(id)item
{
	if([item isKindOfClass:[CCPType class]]){
		return NO;
	}
	return YES;
}

-(id) outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if([item isKindOfClass:[CCPGroup class]]){
		return [item groupName];
	}
	if([item isKindOfClass:[CCPType class]]){
		return [item typeName];
	}
	if([item isKindOfClass:[METSubGroup class]]){
		return [item groupName];
	}
	return nil;
}

-(NSMenu*) outlineView:(NSOutlineView*)outlineView
menuForTableColumnItem:(NSTableColumn*)column
				byItem:(id)item
{
	if(![item isKindOfClass:[CCPType class]]){
		return nil;
	}
	
	NSArray *skills = [item prereqs];
	
	NSMenu *menu = [[[NSMenu alloc]initWithTitle:@"Menu"]autorelease];
	
	NSMenuItem *menuItem;
    menuItem = [[NSMenuItem alloc]initWithTitle: NSLocalizedString( @"View Item Details", @"View Item Details menu item title" )
                                         action:@selector(displaySkillWindow:)
                                  keyEquivalent:@""];
	[menuItem setRepresentedObject:item];
	[menu addItem:menuItem];
	[menuItem release];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	menuItem = [[NSMenuItem alloc]initWithTitle:[NSString stringWithFormat:
												 NSLocalizedString(@"Add %@ to plan",
																   @"add an item to the skill plan"),
												 [item typeName]]
                                         action:@selector(menuAddSkillClick:)
                                  keyEquivalent:@""];
	
	[menuItem setRepresentedObject:skills];
	[menu addItem:menuItem];
	[menuItem release];
	
	return menu;
}

/*display a tooltip*/
- (NSString *)outlineView:(NSOutlineView *)ov
		   toolTipForCell:(NSCell *)cell
					 rect:(NSRectPointer)rect
			  tableColumn:(NSTableColumn *)tc
					 item:(id)item
			mouseLocation:(NSPoint)mouseLocation
{
	return nil;
}

#pragma mark drag and drop support

- (BOOL)outlineView:(NSOutlineView *)outlineView
		 writeItems:(NSArray *)items
	   toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *array = [NSMutableArray array];
	
	//FIXME: TODO: type could also be a CCPGroup item
	
	for(CCPType *type in items){
		if([type isKindOfClass:[CCPType class]]){
			[array addObjectsFromArray:[type prereqs]];
		}else{
			return NO;
		}
	}
	
	[pboard declareTypes:[NSArray arrayWithObject:MTSkillArrayPBoardType] owner:self];
	
	NSMutableData *data = [[NSMutableData alloc]init];
	
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc]initForWritingWithMutableData:data];
	[archiver setOutputFormat:NSPropertyListBinaryFormat_v1_0];
	[archiver encodeObject:array];
	[archiver finishEncoding];
	
	[pboard setData:data forType:MTSkillArrayPBoardType];
	
	[archiver release];
	[data release];
	
	return YES;
}

@end
