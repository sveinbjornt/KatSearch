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

@interface WindowController ()
{
    IBOutlet NSTextField *searchField;
    IBOutlet NSPopUpButton *volumesPopupButton;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSTextField *numResultsTextField;
    IBOutlet NSTableView *tableView;
    IBOutlet NSButton *searchButton;
    IBOutlet NSPathControl *pathControl;
    
    IBOutlet NSMenu *itemContextualMenu;
    IBOutlet NSMenu *openWithSubMenu;
    IBOutlet NSMenu *columnsMenu;
    
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
    
    [tableView setDoubleAction:@selector(rowDoubleClicked:)];
    [tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
    [self.window makeFirstResponder:searchField];
}

- (void)windowWillClose:(NSNotification *)notification {
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

#pragma mark - Search

- (IBAction)search:(id)sender {
    if ([task isRunning]) {
        NSLog(@"Stopping task");
        [task stop];
        return;
    }
    
    NSLog(@"Starting task");
    [searchField setEnabled:NO];
    [pathControl setURL:nil];
    [progressIndicator setHidden:NO];
    [progressIndicator startAnimation:self];
    [numResultsTextField setStringValue:@""];
    
    results = [NSMutableArray array];
    [tableView reloadData];
    
    task = [[SearchTask alloc] initWithDelegate:self];
    task.searchString = [searchField stringValue];
    task.volume = [[volumesPopupButton selectedItem] toolTip];
    
    [task start];
    
    [searchButton setTitle:@"Stop"];
}

#pragma mark - SearchTaskDelegate

- (void)taskResultsFound:(NSArray *)items {
    [results addObjectsFromArray:items];
    [tableView reloadDataPreservingSelection];
    [numResultsTextField setStringValue:[NSString stringWithFormat:@"%lu items", [results count]]];
}

- (void)taskDidFinish:(SearchTask *)task {
    [searchField setEnabled:YES];
    [progressIndicator stopAnimation:self];
    [progressIndicator setHidden:YES];
    [searchButton setTitle:@"Search"];
    
    [tableView reloadDataPreservingSelection];
    
    [numResultsTextField setStringValue:[NSString stringWithFormat:@"%lu items", [results count]]];
    task = nil;
    NSLog(@"Task finished");
}

#pragma mark - Item actions

- (NSIndexSet *)selectedItems {
    NSIndexSet *sel = [tableView selectedRowIndexes];
    return sel;
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
    [[self selectedItems] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop){
        SearchItem *item = results[row];
        [item open];
    }];
}

- (IBAction)openWith:(id)sender {
    NSString *appPath = [sender toolTip];
    NSIndexSet *selectedIndices = [self selectedItems];
    
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
    
    [selectedIndices enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop){
        SearchItem *item = results[row];
        NSLog(@"Opening %@ with app %@", item.path, appPath);
        [item openWith:appPath];
    }];
}

- (IBAction)showInFinder:(id)sender {
    [[self selectedItems] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop){
        SearchItem *item = results[row];
        [item showInFinder];
    }];
}

- (IBAction)getInfo:(id)sender {
    [[self selectedItems] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop){
        SearchItem *item = results[row];
        [item getInfo];
    }];
}

- (IBAction)quickLook:(id)sender {
    [[self selectedItems] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop){
        SearchItem *item = results[row];
        [item quickLook];
    }];
}

- (void)copy:(id)sender {
    [self copyFiles:self];
}

- (IBAction)copyFiles:(id)sender {
    NSMutableArray *items = [NSMutableArray array];
    [[tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop){
        SearchItem *item = results[row];
        if ([[NSFileManager defaultManager] fileExistsAtPath:item.path]) {
            [items addObject:item.path];
        }
    }];

    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    [pasteBoard clearContents];
    
    [pasteBoard declareTypes:@[NSFilenamesPboardType] owner:nil];
    [pasteBoard setPropertyList:items forType:NSFilenamesPboardType];
    
    NSString *strRep = [items componentsJoinedByString:@"\n"];
    [pasteBoard setString:strRep forType:NSStringPboardType];
}

#pragma mark - Contextual menus

- (void)menuWillOpen:(NSMenu *)menu {
    if (menu == itemContextualMenu) {
//        NSMenu *servicesMenu = [[NSApplication sharedApplication] servicesMenu];
//        for (NSMenuItem *item in [servicesMenu itemArray]) {
//            NSLog(@"%@", item.title);
//            [menu addItem:[item copy]];
//        }
        
        NSString *copyTitle = @"";
        NSString *qlTitle = @"";
        NSUInteger numSelectedFiles = [[tableView selectedRowIndexes] count];
        if (numSelectedFiles > 1) {
            copyTitle = [NSString stringWithFormat:@"Copy %lu files", (unsigned long)numSelectedFiles];
            qlTitle = [NSString stringWithFormat:@"Quick Look %lu files", (unsigned long)numSelectedFiles];
        } else {
            SearchItem *item = results[[tableView selectedRow]];
            copyTitle = [NSString stringWithFormat:@"Copy “%@”", item.name];
            qlTitle = [NSString stringWithFormat:@"Quick Look “%@”", item.name];
        }
        [[menu itemWithTag:1] setTitle:qlTitle];
        [[menu itemWithTag:2] setTitle:copyTitle];
    }
    else if (menu == openWithSubMenu) {
    
        NSUInteger selected = [tableView selectedRow];
        if ([tableView selectedRow] == -1) {
            return;
        }
        
        SearchItem *item = results[selected];
        if (!item) {
            return;
        }
        
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
    
    if ([[tc identifier] isEqualToString:@"Name"]) {
        
        cellView = [tv makeViewWithIdentifier:@"Name" owner:self];
        
        SearchItem *item = results[row];
        cellView.textField.stringValue = item.name;
        cellView.imageView.objectValue = item.icon;
        
        return cellView;
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
    if (selectedRow < 0 || selectedRow >= [results count]) {
        return;
    }
    
    SearchItem *item = results[selectedRow];
    [pathControl setURL:[NSURL fileURLWithPath:item.path]];
}

@end
