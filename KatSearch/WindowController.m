/*
 Copyright (c) 2018, Sveinbjorn Thordarson <sveinbjorn@sveinbjorn.org>
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

#import "WindowController.h"
#import "AppDelegate.h"
#import "SearchItem.h"
#import "NSTableView+PreserveSelection.h"
#import "NSWorkspace+Additions.h"

#define VALUES_KEYPATH(X) [NSString stringWithFormat:@"values.%@", (X)]

@interface WindowController ()
{
    IBOutlet NSPopUpButton *itemTypePopupButton;
    IBOutlet NSPopUpButton *matchCriterionPopupButton;
    IBOutlet NSTextField *searchField;
    IBOutlet NSPopUpButton *volumesPopupButton;
    IBOutlet NSButton *searchOptionsButton;
    IBOutlet NSButton *authenticateButton;
    
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSTextField *numResultsTextField;
    
    IBOutlet NSTableView *tableView;
    IBOutlet NSPathControl *pathControl;
    
    IBOutlet NSButton *searchButton;
    
    IBOutlet NSMenu *itemContextualMenu;
    IBOutlet NSMenu *openWithSubMenu;
    IBOutlet NSMenu *columnsMenu;
    IBOutlet NSMenu *searchOptionsMenu;
    
    NSMutableArray *results;
    SearchTask *task;
}
@end

@implementation WindowController

#pragma mark - NSWindowDelegate

- (void)windowDidLoad {
    [super windowDidLoad];

    // Put application icon in window title bar
    [self.window setRepresentedURL:[NSURL URLWithString:@""]];
    [[self.window standardWindowButton:NSWindowDocumentIconButton] setImage:[NSApp applicationIconImage]];
    
    // Configure table view
    [tableView setDoubleAction:@selector(rowDoubleClicked:)];
    [tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
    
    // Load system lock image as icon for button
    NSImage *lockIcon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kLockedIcon)];
    [lockIcon setSize:NSMakeSize(16, 16)];
    [authenticateButton setImage:lockIcon];
    
    [self setObserveDefaults:YES];
    
    [self.window setInitialFirstResponder:searchField];
    [self.window makeFirstResponder:searchField];
}

- (void)windowWillClose:(NSNotification *)notification {
    [task stop];
    
    AppDelegate *delegate = [[NSApplication sharedApplication] delegate];
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

#pragma mark -

- (IBAction)saveDocument:(id)sender {
    
    NSSavePanel *sPanel = [NSSavePanel savePanel];
    [sPanel setPrompt:@"Save"];
    [sPanel setNameFieldStringValue:@"SearchResults.txt"];
    
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
    
    if ([keyPath hasSuffix:@"ShowPathBar"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowPathBar"] && [tableView selectedRow] != -1) {
            [self showPathBar];
        } else {
            [self hidePathBar];
        }
    }
}

- (void)setObserveDefaults:(BOOL)observeDefaults {
    NSArray *defaults = @[@"ShowPathBar"];
    
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
        NSLog(@"Stopping task");
        [task stop];
        return;
    }
    
    [self.window setTitle:[NSString stringWithFormat:@"“%@” - KatSearch", [searchField stringValue]]];
    
    NSLog(@"Starting task");
    
    [self setSearchControlsEnabled:NO];
    
    [self hidePathBar];
    [pathControl setURL:nil];
    
    [progressIndicator setHidden:NO];
    [progressIndicator startAnimation:self];
    
    [numResultsTextField setStringValue:@""];
    
    [searchButton setTitle:@"Stop"];
    
    // Clear results
    results = [NSMutableArray array];
    [tableView reloadData];
    
    // Configure task
    task = [[SearchTask alloc] initWithDelegate:self];
    task.searchString = [searchField stringValue];
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
    
    task.caseSensitive = [[NSUserDefaults standardUserDefaults] boolForKey:@"SearchCaseSensitive"];
    task.skipPackages = [[NSUserDefaults standardUserDefaults] boolForKey:@"SearchSkipPackages"];
    task.skipInvisibles = [[NSUserDefaults standardUserDefaults] boolForKey:@"SearchSkipInvisibles"];
    task.skipInappropriate = [[NSUserDefaults standardUserDefaults] boolForKey:@"SearchSkipSystemFolder"];
    task.negateSearchParams = [[NSUserDefaults standardUserDefaults] boolForKey:@"SearchInvertSearch"];
    
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

#pragma mark - SearchTaskDelegate

- (void)taskResultsFound:(NSArray *)items {
    [results addObjectsFromArray:items];
    [tableView reloadDataPreservingSelection];
    [numResultsTextField setStringValue:[NSString stringWithFormat:@"Found %lu items", [results count]]];
    
    [[[tableView tableColumnWithIdentifier:@"Items"] headerCell] setStringValue:[NSString stringWithFormat:@"Items (%lu)", [results count]]];
    
}

- (void)taskDidFinish:(SearchTask *)task {
    [self setSearchControlsEnabled:YES];
    
    [progressIndicator stopAnimation:self];
    [progressIndicator setHidden:YES];
    
    [searchButton setTitle:@"Search"];
    
    [tableView reloadDataPreservingSelection];
    
    [numResultsTextField setStringValue:[NSString stringWithFormat:@"Found %lu items", [results count]]];
    task = nil;
    NSLog(@"Task finished");
}

#pragma mark - Authentication

- (IBAction)toggleAuthentication:(id)sender {
//    if (isRefreshing) {
//        NSBeep();
//        return;
//    }
//
//    if (!authenticated) {
//        OSStatus err = [self authenticate];
//        if (err == errAuthorizationSuccess) {
//            authenticated = YES;
//        } else {
//            if (err != errAuthorizationCanceled) {
//                NSBeep();
//                NSLog(@"Authentication failed: %d", err);
//            }
//            return;
//        }
//    } else {
//        [self deauthenticate];
//    }
//
    static BOOL authenticated = NO;
    authenticated = !authenticated;
    OSType iconID = authenticated ? kUnlockedIcon : kLockedIcon;
    NSImage *img = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(iconID)];
    [img setSize:NSMakeSize(16, 16)];
//    NSString *actionName = authenticated ? @"Deauthenticate" : @"Authenticate";
    NSString *ttip = authenticated ? @"Deauthenticate" : @"Authenticate to view all system processes";
//
    [authenticateButton setImage:img];
    [authenticateButton setToolTip:ttip];
//    [authenticateMenuItem setImage:img];
//    [authenticateMenuItem setTitle:actionName];
//    [authenticateMenuItem setToolTip:ttip];
//
//    [self refresh:self];
}

- (OSStatus)authenticate {
//    OSStatus err = noErr;
//    const char *toolPath = [[self lsofPath] fileSystemRepresentation];
//
//    AuthorizationItem myItems = { kAuthorizationRightExecute, strlen(toolPath), &toolPath, 0 };
//    AuthorizationRights myRights = { 1, &myItems };
//    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
//
//    // Create authorization reference
//    err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
//    if (err != errAuthorizationSuccess) {
//        return err;
//    }
//
//    // Pre-authorize the privileged operation
//    err = AuthorizationCopyRights(authorizationRef, &myRights, kAuthorizationEmptyEnvironment, flags, NULL);
//    if (err != errAuthorizationSuccess) {
//        return err;
//    }
//
    return noErr;
}

- (void)deauthenticate {
//    if (authorizationRef) {
//        AuthorizationFree(authorizationRef, kAuthorizationFlagDestroyRights);
//        authorizationRef = NULL;
//    }
//    authenticated = NO;
}

#pragma mark - Path Bar

- (void)showPathBar {
    if ([pathControl isHidden] == NO) {
        return;
    }
    
    NSView *borderView = [[tableView superview] superview];
    
    NSRect pathCtrlRect = [pathControl frame];
    NSRect borderViewRect = [borderView frame];
    CGFloat height = pathCtrlRect.size.height + 3;
    
    borderViewRect.origin.y += height;
    borderViewRect.size.height -= height;
    
    [borderView setFrame:borderViewRect];
    [pathControl setHidden:NO];
}

- (void)hidePathBar {
    if ([pathControl isHidden]) {
        return;
    }
    
    NSView *borderView = [[tableView superview] superview];
    
    NSRect pathCtrlRect = [pathControl frame];
    NSRect borderViewRect = [borderView frame];
    CGFloat height = pathCtrlRect.size.height + 3;
    
    borderViewRect.origin.y -= height;
    borderViewRect.size.height += height;
    
    [borderView setFrame:borderViewRect];
    [pathControl setHidden:YES];
}

#pragma mark - Item actions

- (NSMutableArray *)selectedItems {
    NSMutableArray *items = [NSMutableArray array];
    
    if ([pathControl clickedPathItem]) {
        NSString *path = [[[pathControl clickedPathItem] URL] path];
        SearchItem *item = [[SearchItem alloc] initWithPath:path];
        [items addObject:item];
        return items;
    }
    else {
        NSIndexSet *sel = [tableView selectedRowIndexes];
        [sel enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop){
            SearchItem *item = results[row];
            [items addObject:item];
        }];
    }
    
    return items;
//    if ([sel containsIndex:[tableView clickedRow]]) {
//        return sel;
//    } else {
//        return [NSIndexSet indexSetWithIndex:[tableView clickedRow]];
//    }
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

- (void)copySelectedFilesToPasteboard:(NSPasteboard *)pboard {
    NSMutableArray *paths = [NSMutableArray array];

    for (SearchItem *item in [self selectedItems]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:item.path]) {
                [paths addObject:item.path];
            }
    }
    
    [pboard clearContents];
    [pboard declareTypes:@[NSFilenamesPboardType] owner:nil];
    [pboard setPropertyList:paths forType:NSFilenamesPboardType];
    
    NSString *strRep = [paths componentsJoinedByString:@"\n"];
    [pboard setString:strRep forType:NSStringPboardType];
}

#pragma mark - Contextual menus

- (IBAction)searchOptionsButtonClicked:(id)sender {
    [searchOptionsMenu popUpMenuPositioningItem:nil atLocation:[sender frame].origin inView:[sender superview]];
}

- (void)menuWillOpen:(NSMenu *)menu {
    
    if (menu == itemContextualMenu) {

        NSMutableArray *items = [self selectedItems];
        NSUInteger numSelectedFiles = [items count];
        
        NSString *copyTitle = @"";
        NSString *qlTitle = @"";
        
        if (numSelectedFiles == 0) {
            return;
        }
        else if (numSelectedFiles > 1) {
            copyTitle = [NSString stringWithFormat:@"Copy %lu files", (unsigned long)numSelectedFiles];
            qlTitle = [NSString stringWithFormat:@"Quick Look %lu files", (unsigned long)numSelectedFiles];
        } else {
            SearchItem *item = items[0];
            NSString *name = item.name;
            
            copyTitle = [NSString stringWithFormat:@"Copy “%@”", name];
            qlTitle = [NSString stringWithFormat:@"Quick Look “%@”", name];
        }
        [[menu itemWithTag:1] setTitle:qlTitle];
        [[menu itemWithTag:2] setTitle:copyTitle];
    }
    else if (menu == openWithSubMenu) {
    
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

#pragma mark - Text field delegate

- (void)controlTextDidChange:(NSNotification *)obj {
    [searchButton setEnabled:[[searchField stringValue] length]];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [results count];
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)tc row:(NSInteger)row {
    if (row < 0 || row >= [results count]) {
        return nil;
    }
    
    NSTableCellView *cellView;
    SearchItem *item = results[row];
    
    if ([[tc identifier] isEqualToString:@"Items"]) {
        
        cellView = [tv makeViewWithIdentifier:@"Items" owner:self];
        
        SearchItem *item = results[row];
        cellView.textField.stringValue = item.name;
        cellView.imageView.objectValue = item.icon;
        
    } else if ([[tc identifier] isEqualToString:@"Kind"]) {
        cellView = [tv makeViewWithIdentifier:@"Kind" owner:self];
        cellView.textField.stringValue = item.kind;
    } else if ([[tc identifier] isEqualToString:@"Date Modified"]) {
        cellView = [tv makeViewWithIdentifier:@"Date Modified" owner:self];
        cellView.textField.stringValue = item.kind;
    } else if ([[tc identifier] isEqualToString:@"Size"]) {
        cellView = [tv makeViewWithIdentifier:@"Size" owner:self];
        cellView.textField.stringValue = [item sizeString];
    }
    
    return cellView;
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    NSMutableArray *filenames = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
    NSInteger index = [rowIndexes firstIndex];
    
    while (NSNotFound != index) {
        SearchItem *item = results[index];
        [filenames addObject:item.path];
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
        NSURL *fileURL = [NSURL fileURLWithPath:item.path];
        [pathControl setURL:fileURL];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowPathBar"]) {
            [self showPathBar];
        }
    } else {
        [pathControl setURL:nil];
        [self hidePathBar];
    }
}

@end
