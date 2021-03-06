//
//  MarketViewController.h
//  Mac Eve Tools
//
//  Created by Andrew Salamon on 5/20/13.
//  Copyright (c) 2013 Sebastian Kruemling. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "METPluggableView.h"

@class MarketOrders;
@class MetTableHeaderMenuManager;

@interface MarketViewController : NSViewController <METPluggableView,NSTableViewDataSource>
{
    IBOutlet NSTableView *orderTable;
    IBOutlet NSNumberFormatter *currencyFormatter;
    
    Character *character;
    id<METInstance> app;
    MarketOrders *orders;
    MetTableHeaderMenuManager *headerMenuManager;
    NSMutableArray *dbOrders; // orders pulled from the database
}
@property (readwrite,retain,nonatomic) Character *character;
@property (readonly,retain) NSMutableArray *dbOrders;
@end
