/*
    Copyright (c) 2018-2019, Sveinbjorn Thordarson <sveinbjorn@sveinbjorn.org>
    All rights reserved.

    Redistribution and use in source and binary forms, with or without modification,
    are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright notice, this
    list of conditions and the following disclaimer in the documentation and/or other
    materials provided with the distribution.

    3. Neither the name of the copyright holder nor the names of its contributors may
    be used to endorse or promote products derived from this software without specific
    prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
    IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
    INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
    NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
    PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
    WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

#import "SearchController.h"
#import "AppDelegate.h"
#import "SearchItem.h"
#import "SearchQuery.h"
#import "NSTableView+PreserveSelection.h"
#import "NSWorkspace+Additions.h"
#import "STVolumesPopupButton.h"
#import "STPathControl.h"
#import "SearchFilterField.h"
#import "Alerts.h"
#import "NSSharingServicePicker+ESSSharingServicePickerMenu.h"
#import "Common.h"

@interface SearchController ()
{
    IBOutlet NSPopUpButton *itemTypePopupButton;
    IBOutlet NSPopUpButton *matchCriterionPopupButton;
    IBOutlet NSTextField *searchField;
    IBOutlet STVolumesPopupButton *volumesPopupButton;
    IBOutlet NSButton *searchOptionsButton;
    IBOutlet NSButton *authenticateButton;
    
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSProgressIndicator *smallProgressIndicator;
    IBOutlet NSTextField *numResultsTextField;
    
    IBOutlet NSTableView *tableView;
    IBOutlet NSScrollView *scrollView;
    IBOutlet NSPathControl *pathBar;
    IBOutlet STPathControl *pathControl;
    IBOutlet SearchFilterField *filterTextField;
    
    IBOutlet NSButton *searchButton;
    
    IBOutlet NSMenu *itemContextualMenu;
    IBOutlet NSMenu *openWithSubMenu;
    IBOutlet NSMenu *columnsMenu;
    IBOutlet NSMenu *searchOptionsMenu;
    
    NSMutableArray *results;
    SearchTask *task;
    NSTimer *filterTimer;
    
    SearchQuery *startingQuery;
}
@end

@implementation SearchController

+ (instancetype)newController {
    return [[[self class] alloc] initWithWindowNibName:@"SearchWindow"];
}

+ (instancetype)newControllerWithSearchQuery:(SearchQuery *)query {
    return [[[self class] alloc] initWithSearchQuery:query];
}

- (instancetype)initWithSearchQuery:(SearchQuery *)query {
    self = [[[self class] alloc] initWithWindowNibName:@"SearchWindow"];
    if (self) {
        startingQuery = query;
    }
    return self;
}

#pragma mark - NSWindowDelegate

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [self.window registerForDraggedTypes:@[NSFilenamesPboardType]];
//    [[self.window contentView] setWantsLayer:YES];
//    [scrollView setWantsLayer:YES];
//    [tableView setCanDrawSubviewsIntoLayer:YES];
//    [tableView setValue:@(0) forKey:@"_animationDuration"];
    
    // Put application icon in window title bar
    [self.window setRepresentedURL:[NSURL URLWithString:@""]];
    [[self.window standardWindowButton:NSWindowDocumentIconButton] setImage:[NSApp applicationIconImage]];
    
    // Configure table view
    [tableView setRowHeight:18.0f];
    [tableView setDoubleAction:@selector(rowDoubleClicked:)];
    [tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
    
    // Hide columns not enabled in Defaults
    for (NSTableColumn *col in [tableView tableColumns]) {
        NSString *identifier = [col identifier];
        if ([COLUMNS containsObject:identifier]) {
            NSString *defKey = [NSString stringWithFormat:@"%@%@", COL_DEFAULT_PREFIX, identifier];
            [col setHidden:![DEFAULTS boolForKey:defKey]];
        }
    }
    if ([DEFAULTS boolForKey:@"PreviouslyLaunched"] == NO) {
        NSTableColumn *itemsCol = [tableView tableColumnWithIdentifier:@"Items"];
        [itemsCol setWidth:200.f];
        [self.window center];
    }
    
    [pathBar setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
    
    // Register to receive authorization change notifications
    [[NSNotificationCenter defaultCenter] addObserverForName:AUTHCHANGE_NOTIFICATION
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      NSLog(@"Authorized: %d", [APP_DELEGATE isAuthenticated]);
                                                      [self authenticationStatusChanged];
                                                  }];
    
    // Load system lock image as icon for button
    NSImage *lockIcon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kLockedIcon)];
    [lockIcon setSize:NSMakeSize(16, 16)];
    [authenticateButton setImage:lockIcon];
    
    [self setObserveDefaults:YES];
    
    [self.window setInitialFirstResponder:searchField];
    [self.window makeFirstResponder:searchField];
    [self.window setMovableByWindowBackground:YES];
    
    NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    [tableView setSortDescriptors:@[sortDescriptor]];
    
    [self authenticationStatusChanged];
    [self adjustBottomControls];
    
    SearchQuery *sq = startingQuery ? startingQuery : [SearchQuery defaultQuery];
    [self loadQuery:sq];
    if (startingQuery) {
        [self search:self];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    [task stop];
    [self setObserveDefaults:NO];
    AppDelegate *delegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    [delegate performSelector:@selector(windowDidClose:) withObject:self afterDelay:0.05];
}

- (BOOL)window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu *)menu {
    // Prevent popup menu when window icon/title is cmd-clicked
    return NO;
}

- (BOOL)window:(NSWindow *)window shouldDragDocumentWithEvent:(NSEvent *)event from:(NSPoint)dragImageLocation withPasteboard:(NSPasteboard *)pasteboard {
    // Prevent dragging of title bar icon
    return NO;
}

#pragma mark - Load

- (void)loadQuery:(SearchQuery *)query {
    // Configure interface controls according to the values
    // contained in the SearchQuery object
    [itemTypePopupButton selectItemWithTitle:query[@"filetype"]];
    [matchCriterionPopupButton selectItemWithTitle:query[@"matchtype"]];
    [searchField setStringValue:query[@"searchstring"]];
    [volumesPopupButton selectItemWithMountPoint:query[@"volume"]];
    
    [[searchOptionsMenu itemWithTitle:@"Case Sensitive"] setState:[query[@"casesensitive"] boolValue]];
    [[searchOptionsMenu itemWithTitle:@"Skip Package Contents"] setState:[query[@"skippackages"] boolValue]];
    [[searchOptionsMenu itemWithTitle:@"Skip Invisible Files"] setState:[query[@"skipinvisibles"] boolValue]];
    [[searchOptionsMenu itemWithTitle:@"Skip System Folder"] setState:[query[@"skipsystemfolder"] boolValue]];
}

- (void)saveQuery:(SearchQuery *)query {
    [query saveAsRecentSearch];
}

- (SearchQuery *)queryFromControls {
    // Create search query dict from the state of search controls
    return [[SearchQuery alloc] initWithSearchQueryDictionary:@{
        @"filetype": [itemTypePopupButton titleOfSelectedItem],
        @"matchtype": [matchCriterionPopupButton titleOfSelectedItem],
        @"searchstring": [searchField stringValue],
        @"volume": [volumesPopupButton mountPointOfSelectedItem],
        @"casesensitive": @((BOOL)[[searchOptionsMenu itemWithTitle:@"Case Sensitive"] state]),
        @"skippackages": @((BOOL)[[searchOptionsMenu itemWithTitle:@"Skip Package Contents"] state]),
        @"skipinvisibles": @((BOOL)[[searchOptionsMenu itemWithTitle:@"Skip Invisible Files"] state]),
        @"skipsystemfolder": @((BOOL)[[searchOptionsMenu itemWithTitle:@"Skip System Folder"] state]),
    }];
}

#pragma mark - Save to file

- (IBAction)saveDocument:(id)sender {
    
    NSSavePanel *sPanel = [NSSavePanel savePanel];
    [sPanel setPrompt:@"Save"];
    
    [sPanel setNameFieldStringValue:[NSString stringWithFormat:@"SearchResults-%@.txt", [searchField stringValue]]];
    
    NSMutableArray *res = results;
    [sPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result != NSModalResponseOK) {
            return;
        }
        
        NSMutableArray *paths = [NSMutableArray array];
        for (SearchItem *item in res) {
            [paths addObject:item.path];
        }
        
        NSString *strRep = [paths componentsJoinedByString:@"\n"];
        [strRep writeToFile:[[sPanel URL] path] atomically:NO encoding:NSUTF8StringEncoding error:nil];
    }];
}

#pragma mark - Defaults observation

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSString *def = [keyPath substringFromIndex:[@"values." length]];
    if ([def hasSuffix:@"ShowPathBar"]) {
        if ([DEFAULTS boolForKey:@"ShowPathBar"] && [tableView selectedRow] != -1) {
            [self showPathBar];
        } else {
            [self hidePathBar];
        }
    }
    else if ([def hasSuffix:@"ShowFilter"]) {
        if ([DEFAULTS boolForKey:@"ShowFilter"]) {
            [self showFilter];
        } else {
            [self hideFilter];
        }
    }
    else if ([def hasSuffix:@"ShowFullPath"]) {
        [tableView reloadData];
    }
    else if ([def hasPrefix:COL_DEFAULT_PREFIX]) {
        DLog(@"Default %@ changed", keyPath);

        NSString *colName = [def substringFromIndex:[COL_DEFAULT_PREFIX length]];
        NSTableColumn *col = [tableView tableColumnWithIdentifier:colName];
        [col setHidden:![DEFAULTS boolForKey:def]];
    }
//    DLog(@"Default %@ changed", keyPath);

}

- (void)setObserveDefaults:(BOOL)observeDefaults {
    NSMutableArray *defaults = [@[@"ShowPathBar", @"ShowFilter", @"ShowFullPath"] mutableCopy];
    for (NSString *colString in COLUMNS) {
        [defaults addObject:[NSString stringWithFormat:@"%@%@", COL_DEFAULT_PREFIX, colString]];
    }
    
    for (NSString *key in defaults) {
        if (observeDefaults) {
            [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
                                                                      forKeyPath:VALUES_KEYPATH(key)
                                                                         options:NSKeyValueObservingOptionNew
                                                                         context:NULL];
        } else {
            [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:VALUES_KEYPATH(key)];
        }
    }
}

#pragma mark - Search

- (IBAction)search:(id)sender {
    if ([task isRunning]) {
        DLog(@"Stopping task");
        [task stop];
        [self.window makeFirstResponder:searchField];
        return;
    }
    
    [self saveQuery:[self queryFromControls]];
    
    [self.window setTitle:[NSString stringWithFormat:@"“%@” on %@ - KatSearch", [searchField stringValue], [volumesPopupButton titleOfSelectedItem]]];
    
    DLog(@"Starting task");
    
    [self setSearchControlsEnabled:NO];
    
    // Path bar
    [self hidePathBar];
    [pathBar setURL:nil];
    
//    [[[tableView tableColumnWithIdentifier:@"Items"] headerCell] setStringValue:@"Items"];
    
    // Configure progress indicator, move to centre of table view and set it off
    [tableView addSubview:progressIndicator];
    CGFloat x = (NSWidth([tableView bounds]) - NSWidth([progressIndicator frame])) / 2;
    CGFloat y = (NSHeight([tableView bounds]) - NSHeight([progressIndicator frame])) / 2;
    [progressIndicator setControlSize:NSControlSizeRegular];
    [progressIndicator setFrameOrigin:NSMakePoint(x, y)];
    [progressIndicator setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin];
    [progressIndicator setUsesThreadedAnimation:TRUE];
    [progressIndicator startAnimation:self];
    [progressIndicator setHidden:NO];

    [numResultsTextField setStringValue:@"Searching..."];
    
    [searchButton setTitle:@"Stop"];
    
    [self adjustBottomControls];
    
    // Clear results
    results = [NSMutableArray array];
    [tableView reloadData];
    
    // Configure task
    task = [[SearchTask alloc] initWithSearchString:[searchField stringValue] delegate:self];
    task.volume = [[volumesPopupButton selectedItem] toolTip];
    
    if ([itemTypePopupButton selectedTag] == 1) {
        task.filesOnly = YES;
    }
    else if ([itemTypePopupButton selectedTag] == 2) {
        task.directoriesOnly = YES;
    }

    if ([matchCriterionPopupButton selectedTag] == 1) {
        task.exactNameOnly = YES;
    }
    
    task.caseSensitive = [[searchOptionsMenu itemWithTitle:@"Case Sensitive"] state];
    task.skipPackages = [[searchOptionsMenu itemWithTitle:@"Skip Packages"] state];
    task.skipInvisibles = [[searchOptionsMenu itemWithTitle:@"Skip Invisible Files"] state];
    task.skipInappropriate = [[searchOptionsMenu itemWithTitle:@"Skip System Folder"] state];
//    task.negateSearchParams = [DEFAULTS boolForKey:@"SearchInvertSearch"];
    
    if ([APP_DELEGATE isAuthenticated]) {
        [task setAuthorizationRef:[APP_DELEGATE authorization]];
    }
        
    [task start];
}

- (void)setSearchControlsEnabled:(BOOL)enabled {
    [itemTypePopupButton setEnabled:enabled];
    [matchCriterionPopupButton setEnabled:enabled];
    [searchField setEnabled:enabled];
    [volumesPopupButton setEnabled:enabled];
    [authenticateButton setEnabled:enabled];
    [searchOptionsButton setEnabled:enabled];
}

- (IBAction)searchOptionChanged:(id)sender {
    [sender setState:![sender state]];
}

#pragma mark - SearchTaskDelegate

- (void)taskResultsFound:(NSArray *)items {
    
    // Find item property selectors for visible columns
    NSArray *columns = [tableView tableColumns];
    SEL selectors[[columns count]];
    int num = 0;
    for (NSTableColumn *col in columns) {
        if ([col isHidden]) {
            continue;
        }
        NSSortDescriptor *sortDesc = [col sortDescriptorPrototype];
        NSString *sortKey = [sortDesc key];
        if ([sortKey length]) {
            selectors[num] = NSSelectorFromString(sortKey);
            num++;
        }
    }
    
    // Call these selectors on the items to prime the cache
    for (SearchItem *item in items) {
        for (int i = 0; i < num; i++) {
            SEL sel = selectors[i];
//            NSLog(@"%@", NSStringFromSelector(sel));
            [item performSelector:sel];
        }
//        [item prime];
    }
    
    // Make sure we've transitioned to a small progress indicator
    if ([progressIndicator isHidden] == NO) {
        [smallProgressIndicator setUsesThreadedAnimation:TRUE];
        [smallProgressIndicator startAnimation:self];
        [smallProgressIndicator setHidden:NO];
        [progressIndicator setHidden:YES];
    }
    
    [self adjustBottomControls];
    
    // Add items, refresh tbale view
    if ([results count] == 0) {
        [results addObjectsFromArray:items];
        [tableView reloadData];
    } else {
        NSInteger idx1 = [results count];
        [results addObjectsFromArray:items];
        NSInteger idx2 = [results count];
        // TODO: Rethink
        [tableView reloadDataPreservingSelectionFromIndex:idx1 toIndex:idx2];
    }
    
    // Update no. items label
    NSString *cancelled = [task wasKilled] ? @"(cancelled)" : @"";
    NSString *desc = [NSString stringWithFormat:@"Found %lu %@ %@",
                      [results count], [itemTypePopupButton titleOfSelectedItem], cancelled];
    [numResultsTextField setStringValue:desc];
    
//    [[[tableView tableColumnWithIdentifier:@"Items"] headerCell] setStringValue:[NSString stringWithFormat:@"Items (%lu)", [results count]]];
    
    DLog(@"Task results (%d)", (int)[items count]);
}

- (void)taskDidFinish:(SearchTask *)theTask {
    [self setSearchControlsEnabled:YES];
    
    // Stop all progress indicators
    [progressIndicator stopAnimation:self];
    [progressIndicator setHidden:YES];
    [smallProgressIndicator stopAnimation:self];
    [smallProgressIndicator setUsesThreadedAnimation:NO];
    [smallProgressIndicator setHidden:YES];
    [self adjustBottomControls];
    
    [searchButton setTitle:@"Search"];
    
    // Update status text field
    NSString *cancelled = [task wasKilled] ? @"(cancelled)" : @"";
    NSString *desc = [NSString stringWithFormat:@"Found %lu %@ %@",
                      [results count], [itemTypePopupButton titleOfSelectedItem], cancelled];
    [numResultsTextField setStringValue:desc];
    DLog(@"Task finished");
    
    [self.window makeFirstResponder:searchField];
}

#pragma mark - Sort

- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    [results sortUsingDescriptors:[aTableView sortDescriptors]];
    [tableView reloadData];
}

#pragma mark - Filter

- (void)updateFiltering {
    DLog(@"Filtering...");
//    // Filter content
//    int matchingFilesCount = 0;
//    self.content = [self filterContent:self.unfilteredContent numberOfMatchingFiles:&matchingFilesCount];
//
//    // Update outline view header
//    [self updateProcessCountHeader];
//
//    // Update num items label
//    NSString *str = [NSString stringWithFormat:@"Showing %d out of %d items", matchingFilesCount, self.totalFileCount];
//    if (matchingFilesCount == self.totalFileCount) {
//        str = [NSString stringWithFormat:@"Showing all %d items", self.totalFileCount];
//    }
//    [numItemsTextField setStringValue:str];
//
//    [outlineView reloadData];
}

// User typed in search filter
- (void)controlTextDidChange:(NSNotification *)aNotification {
    id o = [aNotification object];
    if (o == filterTextField || o == nil) {
        [self filterTextChanged:NO];
    }
    if (o == searchField || o == nil) {
        [searchButton setEnabled:[[searchField stringValue] length]];
    }
}


#pragma mark - Authentication

- (IBAction)toggleAuthentication:(id)sender {
    BOOL authenticated = [APP_DELEGATE isAuthenticated];
    
    if (!authenticated) {
        OSStatus err = [APP_DELEGATE authenticate];
        if (err != errAuthorizationSuccess) {
            if (err != errAuthorizationCanceled) {
                NSBeep();
                DLog(@"Authentication failed: %d", err);
            }
        }
    } else {
        [APP_DELEGATE deauthenticate];
    }
    [self.window makeKeyAndOrderFront:self];
}

- (void)authenticationStatusChanged {
    BOOL auth = [APP_DELEGATE isAuthenticated];
    
    NSImage *img = [NSImage imageNamed:(auth ?  @"NSLockUnlockedTemplate" : @"NSLockLockedTemplate")];
    NSString *ttip = auth ? @"Deauthenticate" : @"Authenticate to search with root privileges";
    
    [authenticateButton setImage:img];
    [authenticateButton setToolTip:ttip];
}

#pragma mark - Path Bar

- (void)showPathBar {
    if ([pathBar isHidden] == NO) {
        return;
    }
    
    NSView *borderView = [[tableView superview] superview];
    NSRect pathCtrlRect = [pathBar frame];
    NSRect borderViewRect = [borderView frame];
    CGFloat height = pathCtrlRect.size.height + 3;
    
    borderViewRect.origin.y += height;
    borderViewRect.size.height -= height;
    
    [borderView setFrame:borderViewRect];
    [pathBar setHidden:NO];
}

- (void)hidePathBar {
    if ([pathBar isHidden]) {
        return;
    }
    
    NSView *borderView = [[tableView superview] superview];
    
    NSRect pathCtrlRect = [pathBar frame];
    NSRect borderViewRect = [borderView frame];
    CGFloat height = pathCtrlRect.size.height + 3;
    
    borderViewRect.origin.y -= height;
    borderViewRect.size.height += height;
    
    [borderView setFrame:borderViewRect];
    [pathBar setHidden:YES];
}

#pragma mark - Filter

- (void)filterTextChanged:(BOOL)updateNow {
    if (filterTimer) {
        [filterTimer invalidate];
    }
    CGFloat interval = updateNow ? 0.0f : 0.1f;
    filterTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(updateFiltering) userInfo:nil repeats:NO];
    [self adjustBottomControls];
}

- (IBAction)toggleFilter:(id)sender {
    if ([filterTextField isHidden]) {
        [self showFilter];
    } else {
        [self hideFilter];
    }
    [self adjustBottomControls];
}

- (void)showFilter {
    [filterTextField setHidden:NO];
    [self.window makeFirstResponder:filterTextField];
}

- (void)hideFilter {
    [self.window makeFirstResponder:searchField];
    [filterTextField setHidden:YES];
    [filterTextField setStringValue:@""];
    [self filterTextChanged:YES];
}

- (void)adjustBottomControls {
    NSRect filterFrame = [filterTextField frame];
    NSRect spinFrame = [smallProgressIndicator frame];
    NSRect msgFrame = [numResultsTextField frame];

    if ([filterTextField isHidden]) {
        spinFrame.origin.x = filterFrame.origin.x;
    } else {
        spinFrame.origin.x = filterFrame.origin.x + filterFrame.size.width + 10;
    }
    [smallProgressIndicator setFrame:spinFrame];
    
    if ([smallProgressIndicator isHidden]) {
        msgFrame.origin.x = spinFrame.origin.x;
    } else {
        msgFrame.origin.x = spinFrame.origin.x + spinFrame.size.width + 8;
    }
    [numResultsTextField setFrame:msgFrame];
    
}

#pragma mark - Item actions

- (NSMutableArray *)selectedItems {
    NSMutableArray *items = [NSMutableArray array];
    
    if ([pathBar clickedPathItem]) {
        NSString *path = [[[pathBar clickedPathItem] URL] path];
        SearchItem *item = [[SearchItem alloc] initWithPath:path];
        [items addObject:item];
    }
    else {
        NSIndexSet *sel = [tableView selectedRowIndexes];
        [sel enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop){
            SearchItem *item = results[row];
            [items addObject:item];
        }];
    }
    
    return items;
}

- (void)rowDoubleClicked:(id)object {
    NSInteger row = [tableView clickedRow];
    if (row < 0 || row >= [results count]) {
        return;
    }
    
    SearchItem *item = results[row];
    BOOL cmdKeyDown = (([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask) == NSCommandKeyMask);
    
    if (cmdKeyDown) {
        [item showInFinder];
    } else {
        [item open];
    }
}

- (IBAction)open:(id)sender {
    for (SearchItem *item in [self selectedItems]) {
        [item open];
    }
}

- (IBAction)openWith:(id)sender {
    NSString *appPath = [sender toolTip];
    
    if ([[sender title] isEqualToString:@"Select..."]) {
        //create open panel
        NSOpenPanel *oPanel = [NSOpenPanel openPanel];
        [oPanel setAllowsMultipleSelection:NO];
        [oPanel setCanChooseDirectories:NO];
        [oPanel setAllowedFileTypes:@[(NSString *)kUTTypeApplicationBundle]];
        
        // set Applications folder as default directory
        NSArray *applicationFolderPaths = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSLocalDomainMask];
        if ([applicationFolderPaths count]) {
            [oPanel setDirectoryURL:applicationFolderPaths[0]];
        }
    
        //run panel
        if ([oPanel runModal] == NSModalResponseOK) {
            appPath = [[oPanel URLs][0] path];
        } else {
            return;
        }
    }
    
    for (SearchItem *item in [self selectedItems]) {
        [item openWith:appPath];
    }
}

- (IBAction)showInFinder:(id)sender {
    for (SearchItem *item in [self selectedItems]) {
        [item showInFinder];
    }
}

- (IBAction)getInfo:(id)sender {
    for (SearchItem *item in [self selectedItems]) {
        [item getInfo];
    }
}

- (IBAction)quickLook:(id)sender {
    for (SearchItem *item in [self selectedItems]) {
        [item quickLook];
    }
}

- (void)copy:(id)sender {
    [self copyFiles:self];
}

- (IBAction)copyFiles:(id)sender {
    [self copySelectedFilesToPasteboard:[NSPasteboard generalPasteboard]];
}

- (IBAction)moveToTrash:(id)sender {
    NSArray *selItems = [self selectedItems];
    NSUInteger num = [selItems count];
    
    // Potentially destructive operation, ask user to confirm
    BOOL optionKeyDown = (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) == NSAlternateKeyMask);
    if (!optionKeyDown) {
        NSString *q = [NSString stringWithFormat:@"Move %lu items to the Trash?", num];
        NSString *st = @"Hold the option key (⌥) to avoid this prompt.";
        if (num == 1) {
            SearchItem *item = selItems[0];
            NSString *type = item.isDirectory ? @"folder" : @"file";
            q = [NSString stringWithFormat:@"Move the %@ “%@” to the Trash?", type, item.name];
        }
        if (![Alerts proceedAlert:q subText:st withActionNamed:@"Move to Trash"]) {
            return;
        }
    }
    
    // Move items to Trash
    for (SearchItem *item in selItems) {
        [[NSWorkspace sharedWorkspace] moveFileToTrash:item.path];
    }
}

- (IBAction)showOriginal:(id)sender {
    for (SearchItem *item in [self selectedItems]) {
        if ([item isBookmark]) {
            [item showOriginal];
        }
    }
}

#pragma mark - Write items to pasteboard

- (void)copyFiles:(NSArray *)files toPasteboard:(NSPasteboard *)pboard {
    [pboard clearContents];
    [pboard declareTypes:@[NSFilenamesPboardType] owner:nil];
    [pboard setPropertyList:files forType:NSFilenamesPboardType];
    
    NSString *strRep = [files componentsJoinedByString:@"\n"];
    [pboard setString:strRep forType:NSStringPboardType];
}

- (void)copySelectedFilesToPasteboard:(NSPasteboard *)pboard {
    NSMutableArray *files = [NSMutableArray array];
    
    for (SearchItem *item in [self selectedItems]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:item.path]) {
            [files addObject:item.path];
        }
    }
    [self copyFiles:files toPasteboard:pboard];
}

#pragma mark - Contextual menus

- (IBAction)searchOptionsButtonClicked:(id)sender {
    [searchOptionsMenu popUpMenuPositioningItem:nil atLocation:[sender frame].origin inView:[sender superview]];
}

- (void)menuWillOpen:(NSMenu *)menu {
    
    if (menu == itemContextualMenu) {
        
        NSMutableArray *items = [self selectedItems];
        NSUInteger numSelectedFiles = [items count];
        BOOL single = (numSelectedFiles == 1);
        NSString *copyTitle = @"";
        
        if (numSelectedFiles == 0) {
            return;
        }
        else if (numSelectedFiles > 1) {
            copyTitle = [NSString stringWithFormat:@"Copy %lu files", (unsigned long)numSelectedFiles];
        } else {
            SearchItem *item = items[0];
            NSString *name = [item truncatedName:35];
            
            copyTitle = [NSString stringWithFormat:@"Copy “%@”", name];
        }
        [[menu itemWithTag:1] setTitle:copyTitle];
        
        // TODO: Get Share menu working
        // Only show Share menu if a single item is selected
        if (single) {
            NSMenu *shareMenu = [NSSharingServicePicker menuForSharingItems:items
                                                                 withTarget:self
                                                                   selector:@selector(redString:)
                                                            serviceDelegate:nil];
            [[menu itemWithTitle:@"Share"] setSubmenu:shareMenu];
        } else {
            [[menu itemWithTitle:@"Share"] setHidden:YES];
        }
        
//       DLog(@"Hidden: %d", [items[0] isHidden]);
        
        // Unless its defaults have been changed, the Finder is
        // unable to perform any operations on hidden files
        BOOL singleHidden = (single && [items[0] isHidden]);
        [[menu itemWithTitle:@"Get Info"] setEnabled:!singleHidden];
        [[menu itemWithTitle:@"Show in Finder"] setEnabled:!singleHidden];
        [[menu itemWithTitle:@"Quick Look"] setEnabled:!singleHidden];
        
        // Only show Show Original menu if a single item is selected and the item in
        // question is in fact a symlink/alias (or in Apple's parlance, a "bookmark")
        BOOL singleBookmark = (single && [items[0] isBookmark]);
        [[menu itemWithTitle:@"Show Original"] setHidden:!singleBookmark];
        [[menu itemWithTitle:@"Open With"] setHidden:singleBookmark];
    }
    else if (menu == openWithSubMenu) {
    
        // TODO: Use better code e.g. the NSWorkspace additions stuff incorporated into Vienna
        NSMutableArray *items = [self selectedItems];
        if ([items count] == 0) {
            return;
        }
        
        SearchItem *item = items[0];

        [menu removeAllItems];
        
        NSString *defaultApp = [item defaultHandlerApplication];
        
        if (defaultApp == nil) {
            [menu addItemWithTitle:@"None" action:nil keyEquivalent:@""];
        } else {
            NSString *title = [[defaultApp lastPathComponent] stringByDeletingPathExtension];
            title = [NSString stringWithFormat:@"%@ (default)", title];
            
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(openWith:) keyEquivalent:@""];
            
            NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:defaultApp];
            [icon setSize:NSMakeSize(16, 16)];
            
            [menuItem setTarget:self];
            [menuItem setImage:icon];
            [menuItem setToolTip:defaultApp];
            
            [menu addItem:menuItem];
        }

        [menu addItem:[NSMenuItem separatorItem]];
        
        NSArray *handlerApps = [item handlerApplications];
        for (NSString *app in handlerApps) {
            if (defaultApp != nil && [app isEqualToString:defaultApp]) {
                continue;
            }
            
            NSString *title = [[app lastPathComponent] stringByDeletingPathExtension];
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(openWith:) keyEquivalent:@""];
            
            NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:app];
            [icon setSize:NSMakeSize(16, 16)];
            
            [menuItem setTarget:self];
            [menuItem setImage:icon];
            [menuItem setToolTip:app];
            
            [menu addItem:menuItem];
        }
        
        if ([handlerApps count]) {
            [menu addItem:[NSMenuItem separatorItem]];
        }
        
        [menu addItemWithTitle:@"Select..." action:@selector(openWith:) keyEquivalent:@""];
    }
}

#pragma mark - Drag and drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    // Prevent dragging from NSOpenPanels
    // draggingSource returns nil if the source is not in the same application
    // as the destination. We decline any drags from within the app.
    NSArray *files = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
    if ([files count] == 1) {
        // Only allow single folder
        NSString *path = files[0];
        BOOL isDir;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
        if (exists && isDir) {
            return NSDragOperationLink;
        }
    }
    
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSDragOperation op = [self draggingEntered:sender];
    // TODO: Load folder to search
    return (op == NSDragOperationLink);
}

#pragma mark - NSMenuItemValidation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(search:)) {
        return ![task isRunning];
    }
    
    if ([menuItem action] == @selector(saveDocument:)) {
        return ([results count] > 0);
    }
    
    if ([menuItem action] == @selector(copy:)) {
        return ([[self selectedItems] count] > 0);
    }
    
    if ([menuItem action] == @selector(search:)) {
        return [searchButton isEnabled];
    }
    
    if ([menuItem action] == @selector(toggleFilter:)) {
        NSString *title = [filterTextField isHidden] ? @"Filter Results" : @"Hide Filter";
        [menuItem setTitle:title];
    }
    
    // Disable the relevant action menu items if no search items are selected
    if ([menuItem action] == @selector(getInfo:) ||
        [menuItem action] == @selector(showInFinder:) ||
        [menuItem action] == @selector(open:) ||
        [menuItem action] == @selector(quickLook:) ||
        [menuItem action] == @selector(moveToTrash:)) {
        return ([[self selectedItems] count] > 0);
    }
    
    return YES;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [results count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
    if (row < 0 || row >= [results count]) {
        return nil;
    }
    
    NSString *colID = [col identifier];
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:colID owner:self];
    
    cellView.textField.textColor = [NSColor systemGrayColor];
    
    SearchItem *item = results[row];
    id colStr = @"";
    
    // File name / path
    if ([colID isEqualToString:@"Items"]) {
        colStr = [DEFAULTS boolForKey:@"ShowFullPath"] ? item.path : item.name;
        cellView.imageView.objectValue = item.icon;
        cellView.textField.textColor = [NSColor textColor];
    }
    // Kind
    else if ([colID isEqualToString:@"Kind"]) {
        colStr = item.kind;
    }
    // Size
    else if ([colID isEqualToString:@"Size"]) {
        colStr = [DEFAULTS boolForKey:@"HumanFriendlyFileSize"] ? item.sizeString : item.rawSizeString;
    }
    // Date Created
    else if ([colID isEqualToString:@"DateCreated"]) {
        colStr = [DEFAULTS boolForKey:@"HumanFriendlyDates"] ?  item.dateCreatedString : item.dateCreatedISOString;
    }
    // Date Modified
    else if ([colID isEqualToString:@"DateModified"]) {
        colStr = [DEFAULTS boolForKey:@"HumanFriendlyDates"] ? item.dateModifiedString : item.dateModifiedISOString;
    }
    // Date Accessed
    else if ([colID isEqualToString:@"DateAccessed"]) {
        colStr = [DEFAULTS boolForKey:@"HumanFriendlyDates"] ? item.dateAccessedString : item.dateAccessedISOString;
    }
    // User:Group
    else if ([colID isEqualToString:@"UserGroup"]) {
        colStr = [self monospacedString:item.userGroupString];;
    }
    // POSIX permissions
    else if ([colID isEqualToString:@"Permissions"]) {
        // Use monospace font for permissions
        NSString *pStr = [DEFAULTS boolForKey:@"HumanFriendlyPermissions"] ? item.permissionsString : item.permissionsNumberString;
        colStr = [self monospacedString:pStr];
    }
    // Uniform Type Identifier
    else if ([colID isEqualToString:@"UTI"]) {
        colStr = item.UTI;
    }
    // HFS File Type
    else if ([colID isEqualToString:@"FileType"]) {
        NSDictionary *attr = @{ NSFontAttributeName: [NSFont userFixedPitchFontOfSize:[NSFont systemFontSize]] };
        colStr = [[NSAttributedString alloc] initWithString:item.HFSType attributes:attr];
    }
    // HFS Creator Type
    else if ([colID isEqualToString:@"CreatorType"]) {
        NSDictionary *attr = @{ NSFontAttributeName: [NSFont userFixedPitchFontOfSize:[NSFont systemFontSize]] };
        colStr = [[NSAttributedString alloc] initWithString:item.creatorType attributes:attr];
    }
    // MIME Type
    else if ([colID isEqualToString:@"MIMEType"]) {
        colStr = item.MIMEType;
    }
    
    // Visually mark non-existent files
    // TODO: Do something about non-existent files?
//    if (item.exists == NO) {
//        colStr = [self redString:colStr];
//    }
    
    // Set text field string
    if (![colStr isKindOfClass:[NSAttributedString class]]) {
        cellView.textField.stringValue = colStr;
    } else {
        [cellView.textField setAttributedStringValue:colStr];
    }
    
    return cellView;
}

- (NSAttributedString *)redString:(id)str {
    NSString *s = [str isKindOfClass:[NSAttributedString class]] ? [str string] : str;
    NSDictionary *attr = @{ NSForegroundColorAttributeName: [NSColor redColor] };
    return [[NSAttributedString alloc] initWithString:s attributes:attr];
}

- (NSAttributedString *)monospacedString:(NSString *)str {
    NSDictionary *attr = @{ NSFontAttributeName: [NSFont userFixedPitchFontOfSize:[NSFont systemFontSize]] };
    return [[NSAttributedString alloc] initWithString:str attributes:attr];

}

//- (NSAttributedString *)attr:(NSString *)title {
//    NSDictionary *attr = @{ NSForegroundColorAttributeName: [NSColor whiteColor] };
//    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:title attributes:attr];
//
//    NSRange mRange = [[title lowercaseString] rangeOfString:@"test"];
//    if (mRange.location != NSNotFound) {
//        NSDictionary *mattr = @{ NSForegroundColorAttributeName: [NSColor blackColor],
//                                 NSBackgroundColorAttributeName: [NSColor yellowColor],
//                                 };
//
//        [attrStr setAttributes:mattr range:mRange];
//
//        NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
//        [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
//        [attrStr addAttribute:NSParagraphStyleAttributeName
//                        value:paragraphStyle
//                        range:NSMakeRange(0,[title length])];
//
//
////        [attrStr beginEditing];
////        [attrStr applyFontTraits:NSBoldFontMask
////                           range:mRange];
////        [attrStr endEditing];
//
//    }
//
//    return attrStr;
//}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    NSMutableArray *filenames = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
    NSInteger index = [rowIndexes firstIndex];
    
    while (NSNotFound != index) {
        SearchItem *item = results[index];
        if ([[NSFileManager defaultManager] fileExistsAtPath:item.path]) {
            [filenames addObject:item.path];
        } else {
            DLog(@"Not copying, no file at path: %@", item.path);
        }
        index = [rowIndexes indexGreaterThanIndex:index];
    }
    
    [pboard declareTypes:@[NSFilenamesPboardType] owner:nil];
    [pboard setPropertyList:filenames forType:NSFilenamesPboardType];
    
    return YES;
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = [tableView selectedRow];
    if (selectedRow >= 0 && selectedRow < [results count] && [results count]) {
        SearchItem *item = results[selectedRow];
        [pathBar setURL:item.url];
        if ([DEFAULTS boolForKey:@"ShowPathBar"]) {
            [self showPathBar];
        }
    } else {
        [pathBar setURL:nil];
        [self hidePathBar];
    }
}

#pragma mark - NSPathControlDelegate

- (BOOL)pathControl:(NSPathControl *)pathControl shouldDragItem:(NSPathControlItem *)pathItem withPasteboard:(NSPasteboard *)pboard {
    NSString *draggedFile = [[pathItem URL] path];
    [self copyFiles:@[draggedFile] toPasteboard:pboard];
    return YES;
}

@end
