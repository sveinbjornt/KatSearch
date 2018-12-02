//
//  NSTableView+TBHideableTableViewColumns.m
//  Karafun
//
//  Created by Tom Baranes on 31/03/15.
//  Copyright (c) 2015 Tom Baranes. All rights reserved.
//
//	Licensed under the Apache License, Version 2.0 (the "License");
//	you may not use this file except in compliance with the License.
//	You may obtain a copy of the License at
//
//		http://www.apache.org/licenses/LICENSE-2.0
//
//	Unless required by applicable law or agreed to in writing, software
//	distributed under the License is distributed on an "AS IS" BASIS,
//	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//	See the License for the specific language governing permissions and
//	limitations under the License.

#import "NSTableView+TBHideableTableViewColumns.h"

@implementation NSTableView (TBHideableTableViewColumns)

static NSString * const KFTitleKey = @"title";
static NSString * const KFWidthKey = @"width";

#pragma mark - Contextual Menu

- (void)createHideableColumnContextualMenuWithAutoResizingColumns:(BOOL)autoResizingColumns identifierException:(NSArray *)identifierException {
	NSArray *cols = [[NSUserDefaults standardUserDefaults] arrayForKey:KFUserDefaultsSongTableViewColumnState];
	NSMenu *tableHeaderContextMenu = [[NSMenu alloc] initWithTitle:@""];
	if (autoResizingColumns) {
		[self createResizingColumnsItemsForMenu:tableHeaderContextMenu];
	}
	
	[[self headerView] setMenu:tableHeaderContextMenu];
	NSArray *tableColums = [self.tableColumns copy];
	for (NSTableColumn *column in tableColums) {
		if ([identifierException containsObject:column.identifier]) {
			continue;
		}
		
		NSMenuItem *item = [tableHeaderContextMenu addItemWithTitle:[self titleForColumn:column] action:@selector(menuItemPressed:) keyEquivalent:@""];
		[item setTarget:self];
		[item setRepresentedObject:column];
		[item setState:cols ? NSOffState : NSOnState];
		if (cols) {
			[self removeTableColumn:column];
		}
	}
	
	for (NSDictionary *colinfo in cols) {
		NSMenuItem *item = [tableHeaderContextMenu itemWithTitle:[colinfo objectForKey:KFTitleKey]];
		NSTableColumn *column = [item representedObject];
		if (!item || !column) {
			continue;
		}
		
		[item setState:NSOnState];
		[column setWidth:[[colinfo objectForKey:KFWidthKey] floatValue]];
		[self addTableColumn:column];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveTableColumns:) name:NSTableViewColumnDidMoveNotification object:self];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveTableColumns:) name:NSTableViewColumnDidResizeNotification object:self];
}

- (void)createResizingColumnsItemsForMenu:(NSMenu *)tableHeaderContextMenu {
	NSMenuItem *item = [tableHeaderContextMenu addItemWithTitle:[self localizedStringForKey:@"TBHideableTableViewColumnsResizingAllColumns" withDefault:@""]  action:@selector(resizingAllColumn) keyEquivalent:@"TBHideableTableViewColumnsResizingAllColumns"];
	[item setTarget:self];
	
	[tableHeaderContextMenu addItem:[NSMenuItem separatorItem]];
}

- (void)hideColumnWithIdentifiers:(NSArray *)identifiers {
	for (NSString *identifier in identifiers) {
		NSTableColumn *column = [self.tableColumns objectAtIndex:[self columnWithIdentifier:identifier]];
		NSMenuItem *menuItem = [self.headerView.menu itemWithTitle:[self titleForColumn:column]];
		menuItem.state = NSOffState;
		[self removeTableColumn:column];
	}
}

#pragma mark - Localizable

- (NSString *)localizedStringForKey:(NSString *)key withDefault:(NSString *)defaultString {
	static NSBundle *bundle = nil;
	if (bundle == nil) {
		NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"TBHideableTableViewColumns" ofType:@"bundle"];
		bundle = [NSBundle bundleWithPath:bundlePath];
		NSString *language = [[NSLocale preferredLanguages] count]? [NSLocale preferredLanguages][0]: @"en";
		if (![[bundle localizations] containsObject:language]) {
			language = [language componentsSeparatedByString:@"-"][0];
		}

		if ([[bundle localizations] containsObject:language]) {
			bundlePath = [bundle pathForResource:language ofType:@"lproj"];
		}
		bundle = [NSBundle bundleWithPath:bundlePath] ?: [NSBundle mainBundle];
	}
	defaultString = [bundle localizedStringForKey:key value:defaultString table:nil];
	return [[NSBundle mainBundle] localizedStringForKey:key value:defaultString table:nil];
}

#pragma mark - Helper

- (NSString *)titleForColumn:(NSTableColumn *)column {
	NSString *title = [column.title length] == 0 ? NSLocalizedString(column.identifier, nil) : column.title;
	return title;
}

#pragma mark - IBAction

- (void)menuItemPressed:(id)sender {
	BOOL on = [sender state] == NSOnState;
	[sender setState:on ? NSOffState : NSOnState];
	NSTableColumn *column = [sender representedObject];
	if (on) {
		[self removeTableColumn:column];
		[self setNeedsDisplay:YES];
	} else {
		[self addTableColumn:column];
		[self setNeedsDisplay:YES];
		[self resizeToFitContentsForColumn:column];
	}
	[self saveTableColumns:nil];
}

- (void)resizingColumn:(NSMenuItem *)sender {
	NSInteger col = [self clickedColumn];
	if (col == -1) {
		return;
	}
	[self resizeToFitContentsForColumn:[[self tableColumns] objectAtIndex:col]];
}

- (void)resizingAllColumn {
	for (NSTableColumn *column in self.tableColumns) {
		[self resizeToFitContentsForColumn:column];
	}
	[self saveTableColumns:nil];
}

#pragma mark - 

- (void)resizeToFitContentsForColumn:(NSTableColumn *)column {
	if (column.minWidth == column.maxWidth) {
		return;
	}
	
	[column sizeToFit];
	CGFloat maxWidth = column.width;
	NSInteger columnIndex = [self.tableColumns indexOfObject:column];
	for (NSInteger rowIndex = 0; rowIndex < self.numberOfRows; rowIndex++) {
		NSView *view = [self viewAtColumn:columnIndex row:rowIndex makeIfNecessary:NO];
		NSSize size = [view fittingSize];
		if (size.width > maxWidth) {
			maxWidth = size.width + 10.f;
		}
	}
	
	[column setWidth:maxWidth];
}

#pragma mark - Notification

- (void)saveTableColumns:(NSNotification *)notification {
	NSMutableArray *cols = [NSMutableArray array];
	for (NSTableColumn *column in self.tableColumns) {
		NSString *title = [self titleForColumn:column];
		[cols addObject:@{KFTitleKey: title, KFWidthKey: @(column.width)}];
	}
	[[NSUserDefaults standardUserDefaults] setObject:cols forKey:KFUserDefaultsSongTableViewColumnState];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end
