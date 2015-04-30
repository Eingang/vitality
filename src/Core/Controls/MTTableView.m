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

#import "MTTableView.h"

@interface NSObject (MTTableViewDelegate)
// This method on the delegate should return NO if the delegate does not handle the event.
-(BOOL) tableView:(NSTableView*)aTableView keyDownEvent:(NSEvent*)theEvent;
@end

@implementation MTTableView

/*
 Pass the keydown event onto the delegate so it can do something useful with it.
 */

- (void) keyDown:(NSEvent *) event
{
	NSString *str = [event charactersIgnoringModifiers];
	if([str length] == 0){
		[super keyDown:event];
		return;
	}
	unichar ch = [str characterAtIndex:0];
	
	switch (ch) {
		case NSUpArrowFunctionKey:
		case NSDownArrowFunctionKey:
		case NSLeftArrowFunctionKey:
		case NSRightArrowFunctionKey:
			[super keyDown:event];
			return;
		default:
			break;
	}
	
	id del = [self delegate];
	if( [del respondsToSelector:@selector(tableView:keyDownEvent:)] )
    {
        if( ![del tableView:self keyDownEvent:event] )
            [super keyDown:event];
	}
    else
    {
		[super keyDown:event];		
	}
	
	return;
}

- (void)copy:(id)sender
{
    if( [[self delegate] respondsToSelector:@selector(copy:)] )
        [[self delegate] performSelector:@selector(copy:) withObject:self];
}
@end
