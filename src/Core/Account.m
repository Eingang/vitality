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

#import "Account.h"
#import "Config.h"
#import "XmlFetcher.h"
#import "XmlHelpers.h"
#import "Character.h"
#import "CharacterTemplate.h"

#import <libxml/parser.h>
#import <libxml/tree.h>

/* TODO: Add a call to account/AccountStatus.xml.aspx?keyID=${KEYID}&vCode=${VCODE} to get multi-character training end dates
 <?xml version='1.0' encoding='UTF-8'?>
 <eveapi version="2">
 <currentTime>2016-08-09 15:44:03</currentTime>
 <result>
 <paidUntil>2016-12-11 01:26:39</paidUntil>
 <createDate>2012-03-19 21:38:29</createDate>
 <logonCount>1786</logonCount>
 <logonMinutes>149517</logonMinutes>
 <rowset name="multiCharacterTraining" key="trainingEnd" columns="trainingEnd">
 <row trainingEnd="2016-10-07 19:18:00" />
 </rowset>
 </result>
 <cachedUntil>2016-08-09 16:41:03</cachedUntil>
 </eveapi>

 */
@interface Account (AccountPrivate) <XmlFetcherDelegate>
-(void) xmlDocumentFinished:(BOOL)status xmlPath:(NSString*)path xmlDocName:(NSString*)docName;

-(void) downloadXml;

-(NSString*)savePath;

-(BOOL) parseXmlDocument:(xmlDoc*) doc;
-(BOOL) loadXmlDocument;

@end

@implementation Account (AccountPrivate)

/*Generate the save path*/
-(NSString*)savePath
{
	NSString *str = [Config filePath:XMLAPI_CHAR_LIST,keyID,nil];
	return str;
}

-(BOOL) parseXmlDocument:(xmlDoc*)doc
{
	xmlNode *root = xmlDocGetRootElement(doc);
	if(root == NULL){
		NSLog(@"error parsing XML document");
        NSRunAlertPanel(@"Unable to parse XML", @"This does not look like EVE Online's API. Perhaps the API is down or something is getting in the way of the request.", @"Close", nil, nil);
        
		return NO;
	}
	xmlNode *result = findChildNode(root,(xmlChar*)"result");
	if(result == NULL){
		NSLog(@"error parsing XML document");
        NSRunAlertPanel(@"Unable to parse XML", @"This does not look like EVE Online's API. Perhaps the API is down or something is getting in the way of the request.", @"Close", nil, nil);
        
		return NO;
	}
	xmlNode *rowset = findChildNode(result,(xmlChar*)"rowset");
	if(rowset == NULL){
		NSLog(@"error parsing XML document");
        NSRunAlertPanel(@"Unable to parse XML", @"This does not look like EVE Online's API. Perhaps the API is down or something is getting in the way of the request.", @"Close", nil, nil);
        
		return NO;
	}
	
	[self.characters removeAllObjects];
	
	for(xmlNode *cur_node = rowset->children;
		cur_node != NULL;
		cur_node = cur_node->next)
	{
		if(cur_node->type != XML_ELEMENT_NODE){
			continue;
		}
		
		NSString *name = findAttribute(cur_node,(xmlChar*)"name");
		NSString *characterID = findAttribute(cur_node,(xmlChar*)"characterID");
		
		CharacterTemplate *template;
		template = [[CharacterTemplate alloc]
					initWithDetails:name 
					accountId:self.keyID
					verificationCode:self.verificationCode 
					charId:characterID 
					active:YES
					primary:NO];
		
		[characters addObject:template];
		[template release];

	}
	
	return YES;
}

-(void) downloadXml:(BOOL)modalDelegate
{
	XmlFetcher *f = [[XmlFetcher alloc]initWithDelegate:self];
	
	NSString *apiUrl = [Config getApiUrl:XMLAPI_CHAR_LIST 
							   keyID:self.keyID 
								  verificationCode:self.verificationCode
								  charId:nil];
	
	if(modalDelegate){
		[f saveXmlDocument:apiUrl
				   docName:XMLAPI_CHAR_LIST
				  savePath:[self savePath]
			   runLoopMode:NSModalPanelRunLoopMode];
		
	}else{
		[f saveXmlDocument:apiUrl
			   docName:XMLAPI_CHAR_LIST
			  savePath:[self savePath]];
	}
	[f release];	
}

-(void) downloadXml
{
	[self downloadXml:NO];
}

-(BOOL)loadXmlDocument
{
	xmlDoc *doc = xmlReadFile([[self savePath] fileSystemRepresentation],NULL, 0);
	
	if(doc == NULL){
		NSLog(@"Failed to read %@",[self savePath]);
		return NO;
	}
	
	BOOL rc = [self parseXmlDocument:doc];
	
	xmlFreeDoc(doc);
	
	return rc;
}

-(void) xmlDocumentFinished:(BOOL)status xmlPath:(NSString*)path xmlDocName:(NSString*)docName
{
	if(status == NO){
		NSLog(@"Failed to download %@ to %@",docName,path);
		[delegate accountDidUpdate:self didSucceed:NO];
        
		return;
	}
	
	BOOL rc = [self loadXmlDocument];
    
    NSLog(@"found %ld chars", (unsigned long)[self.characters count]);

	[delegate accountDidUpdate:self didSucceed:rc];
}

-(BOOL) xmlValidateData:(NSData*)xmlData xmlPath:(NSString*)path xmlDocName:(NSString*)docName
{
	BOOL rc = YES;
	const char *bytes = [xmlData bytes];
	
	xmlDoc *doc = xmlReadMemory(bytes,(int)[xmlData length], NULL, NULL, 0);
	
	xmlNode *root_node = xmlDocGetRootElement(doc);
	xmlNode *result = findChildNode(root_node,(xmlChar*)"error");
	
	if(result != NULL){
		NSLog(@"%@",getNodeText(result));
		rc = NO;
        
        NSRunAlertPanel(@"API Error",@"%@", @"Close",nil,nil, getNodeText(result) );
	}
	
	xmlFreeDoc(doc);
	return rc;
}

-(void) xmlDidFailWithError:(NSError*)xmlErrorMessage xmlPath:(NSString*)path xmlDocName:(NSString*)docName
{
	NSLog(@"Connection failed! (%@)",[xmlErrorMessage localizedDescription]);
	
	NSRunAlertPanel(@"API Connection Error", @"%@",@"Close",nil,nil, [xmlErrorMessage localizedDescription]);
}

@end



@implementation Account

@synthesize keyID;
@synthesize verificationCode;
@synthesize accountName;
@synthesize characters;


-(void) addCharacter:(CharacterTemplate*)template
{
	[self.characters addObject:template];
}


-(CharacterTemplate*) findCharacter:(NSString*)charName
{
	for(CharacterTemplate *template in characters){
		if([[template characterName]isEqualToString:charName]){
			return template;
		}
	}
	return nil;
}

-(void) loadAccount:(id<AccountUpdateDelegate>)del runForModalWindow:(BOOL)modal
{
	delegate = del;
    
	[self downloadXml:modal];
}

-(void)loadAccount:(id<AccountUpdateDelegate>)del
{
//#ifdef MACEVEAPI_DEBUG
//	[self loadAccount:del runForModalWindow:NO];
//#else
	[self loadAccount:del runForModalWindow:NO];
//#endif
}

-(NSInteger)characterCount
{
	if(self.characters != nil){
		return [self.characters count];
	}
	return 0;
}

-(void) fetchCharacters:(id<AccountUpdateDelegate>)del
{
	delegate = del;
	[self downloadXml];
}

-(void) dealloc
{
	[keyID release];
	[verificationCode release];
	[characters release];
	[accountName release];
	[super dealloc];
}

-(Account*) init
{
	if(self = [super init]){
		characters = [[NSMutableArray alloc] init];
	}
	return self;
}

-(Account*) initWithDetails:(NSString*)acctID acctKey:(NSString*)key
{
	if(self = [self init]){
		keyID = [acctID retain];
		verificationCode = [key retain];
	}
	
	return self;
}

-(Account*) initWithName:(NSString*)name
{
	if(self = [self init]){
		accountName = [name retain];
	}
	return self;
}

/*

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	NSLog(@"found %ld chars",[characters count]);
	return [characters count];
}

- (id)tableView:(NSTableView *)aTableView 
objectValueForTableColumn:(NSTableColumn *)aTableColumn 
			row:(NSInteger)rowIndex
{
	CharacterTemplate *template = [characters objectAtIndex:rowIndex];
	
	if([[aTableColumn identifier]isEqualToString:@"NAME"]){
		return [template characterName];
	}if([[aTableColumn identifier]isEqualToString:@"ACTIVE"]){
		BOOL active = [template active];
		
		if(active){
			return [NSNumber numberWithInteger:NSOnState];
		}else{
			return [NSNumber numberWithInteger:NSOffState];
		}
	}
	return nil;
}
*/

#pragma mark -
#pragma mark NSCoding protocol
- (id) initWithCoder:(NSCoder *)aDecoder {
	if (self = [super init]) {
		self.accountName = [aDecoder decodeObjectForKey:@"accountName"];
		self.keyID = [aDecoder decodeObjectForKey:@"keyID"];
		self.verificationCode = [aDecoder decodeObjectForKey:@"verificationCode"];
		self.characters = [NSMutableArray arrayWithArray: [aDecoder decodeObjectForKey:@"characters"]];
	}
	return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:self.accountName forKey:@"accountName"];
	[aCoder encodeObject:self.keyID forKey:@"keyID"];
	[aCoder encodeObject:self.verificationCode forKey:@"verificationCode"];
	[aCoder encodeObject:self.characters forKey:@"characters"];
}

@end
