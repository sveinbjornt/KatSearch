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

#import "Common.h"
#import "AppDelegate.h"
#import "SearchController.h"
#import "PreferencesController.h"
#import <MASShortcut/Shortcut.h>

@interface AppDelegate ()
{
    NSMutableArray *windowControllers;
    PreferencesController *prefsController;
    
    IBOutlet NSMenu *openRecentMenu;
    IBOutlet NSMenu *statusMenu;
    NSStatusItem *statusItem;
}
@end

@implementation AppDelegate

+ (void)initialize {
    NSString *defaultsPath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
    [DEFAULTS registerDefaults:[NSDictionary dictionaryWithContentsOfFile:defaultsPath]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    // Associate the shortcut key key with an action
    [[MASShortcutBinder sharedBinder] bindShortcutWithDefaultsKey:@"GlobalShortcut"
                                                         toAction:^{
         if ([[NSApplication sharedApplication] isActive] || ![windowControllers count]) {
             [self animateStatusItem];
             [self newWindow:self];
         }
     }];
    
    windowControllers = [NSMutableArray array];
    
    if (1) { // TODO: Not in status mode
        [self newWindow:self];
    }
    [self showStatusItem];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    if (flag) {
        return NO;
    }

    [self newWindow:self];
    
    return YES;
}

#pragma mark -

- (IBAction)newWindow:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    SearchController *controller = [[SearchController alloc] initWithWindowNibName:@"SearchWindow"];
    [windowControllers addObject:controller];
    [controller showWindow:self];
}

- (void)windowDidClose:(id)sender {
    [windowControllers removeObject:sender];
}

- (void)noteRecentSearch:(SearchTask *)task {
    if ([DEFAULTS boolForKey:@"RememberRecentSearches"] == NO) {
        return;
    }
    
    NSMutableArray *recent = [[DEFAULTS objectForKey:@"RecentSearches"] mutableCopy];
    if (!recent) {
        recent = [NSMutableArray new];
    }
    else if ([recent count] >= NUM_RECENT_SEARCHES) {
        [recent removeLastObject];
    }
    [recent insertObject:[task description] atIndex:0];

    [DEFAULTS setObject:[recent copy] forKey:@"RecentSearches"];
}

- (void)menuWillOpen:(NSMenu *)menu {
    if (menu == statusMenu) {
    }
    else if (menu == openRecentMenu) {
        [menu removeAllItems];
        
        if ([DEFAULTS boolForKey:@"RememberRecentSearches"] == NO) {
            // Construct menu with list of recent searches
            NSArray *recent = [DEFAULTS objectForKey:@"RecentSearches"];
            for (NSString *n in recent) {
                [menu addItemWithTitle:n action:@selector(openRecentSearch:) keyEquivalent: @""];
            }
        }
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:@"Clear Menu" action:@selector(clearRecentSearches:) keyEquivalent: @""];
    }
}

- (IBAction)openRecentSearch:(id)sender {
    // TODO: Implement me!
}

- (IBAction)clearRecentSearches:(id)sender {
    [DEFAULTS setObject:@[] forKey:@"RecentSearches"];
}

#pragma mark - Status Menu

- (void)showStatusItem {
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSImage *icon = [NSImage imageNamed:@"StatusItemIcon"];
    [icon setSize:NSMakeSize(18, 18)];
    [statusItem setImage:icon];
    [statusItem setMenu:statusMenu];
}

- (void)hideStatusItem {
    if (!statusItem) {
        return;
    }
    [[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
    statusItem = nil;
}

- (void)animateStatusItem {
    [statusItem.button setHighlighted:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [statusItem.button setHighlighted:NO];

    });
}

#pragma mark -

- (IBAction)showPreferences:(id)sender {
    if (prefsController == nil) {
        prefsController = [[PreferencesController alloc] initWithWindowNibName:@"PreferencesController"];
    }
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [prefsController showWindow:self];
}

#pragma mark -

- (IBAction)openDonations:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PROGRAM_DONATIONS_URL]];
}

- (IBAction)openWebsite:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PROGRAM_WEBSITE_URL]];
}

- (IBAction)openGitHubWebsite:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PROGRAM_GITHUB_URL]];
}

@end
