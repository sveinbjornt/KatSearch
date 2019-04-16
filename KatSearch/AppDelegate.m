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
#import "WindowController.h"
#import "PreferencesController.h"
#import <MASShortcut/Shortcut.h>

@interface AppDelegate ()
{
    NSMutableArray *windowControllers;
    PreferencesController *prefsController;
    
    IBOutlet NSMenu *openRecentMenu;
}
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    // Associate the preference key with an action
    [[MASShortcutBinder sharedBinder]
     bindShortcutWithDefaultsKey:@"GlobalShortcut"
     toAction:^{
         [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
         if (![windowControllers count]) {
             [self newWindow:self];
         }
     }];
    
    windowControllers = [NSMutableArray array];
    [self newWindow:self];
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
    WindowController *controller = [[WindowController alloc] initWithWindowNibName:@"SearchWindow"];
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
    if (menu == openRecentMenu) {
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

#pragma mark -

- (IBAction)showPreferences:(id)sender {
    if (prefsController == nil) {
        prefsController = [[PreferencesController alloc] initWithWindowNibName:@"PreferencesController"];
    }
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
