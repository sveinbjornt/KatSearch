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
#import "LSUIElementApp.h"
#import "SearchController.h"
#import "SearchQuery.h"
#import <MASShortcut/Shortcut.h>
#import "PrefsController.h"
#import "IntroController.h"
#import "NSWorkspace+Additions.h"

@interface AppDelegate ()
{
    NSMutableArray *windowControllers;
    MASPreferencesWindowController *prefsController;
    IntroController *introWindowController;
    
    IBOutlet NSMenu *mainMenu;
    IBOutlet NSMenu *openRecentMenu;
    IBOutlet NSMenu *statusMenu;
    IBOutlet NSMenuItem *newMenuItem;
    IBOutlet NSMenuItem *menuBarItem;
    IBOutlet NSMenuItem *authenticateMenuItem;
    
    NSStatusItem *statusItem;
    
    AuthorizationRef authorizationRef;
}
@end

@implementation AppDelegate

+ (void)initialize {
    NSString *defaultsPath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
    [DEFAULTS registerDefaults:[NSDictionary dictionaryWithContentsOfFile:defaultsPath]];
}

- (void)awakeFromNib {
    [NSApp setServicesProvider:self];
    [NSApp registerServicesMenuSendTypes:@[NSFilenamesPboardType] returnTypes:@[]];
    
    [self startObservingDefaults];

    // TODO: Set shortcut to New Search menu item
    if (0) {
//        keyCodeStringForKeyEquivalent
//        [newMenuItem setKeyEquivalent:@""];
//        [newMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask];
    } else {
        [newMenuItem setKeyEquivalent:@"N"];
        [newMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask];
    }
//    MASShortcut
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Transition from LSUIElement to regular app if needed
    [self setAppMode:[DEFAULTS boolForKey:@"StatusItemMode"]];
    
    // Associate the shortcut hotkey combo with a new window / bring to front action
    NSArray *wc = windowControllers;
    [[MASShortcutBinder sharedBinder] bindShortcutWithDefaultsKey:SHORTCUT_DEFAULT_NAME
                                                         toAction:^{
         if ([NSApp isActive] || ![wc count]) {
             [self newWindow:self];
         }
     }];
    
    windowControllers = [NSMutableArray new];
    
    // Register to receive authorization change notifications
    [[NSNotificationCenter defaultCenter] addObserverForName:AUTHCHANGE_NOTIFICATION
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      DLog(@"Authorized: %d", [APP_DELEGATE isAuthenticated]);
                                                      [self authenticationStatusChanged];
                                                  }];
    [self authenticationStatusChanged];
    
    if ([DEFAULTS boolForKey:@"AuthenticateOnLaunch"]) {
        [self authenticate];
    }
    
    if ([DEFAULTS boolForKey:@"PreviouslyLaunched"]) {
        if ([DEFAULTS boolForKey:@"StatusItemMode"]) {
            [self showStatusItem];
        } else {
            [self newWindow:self];
        }
    } else {
        [self showIntroWindow:self];
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    if (flag) {
        return NO;
    }
    [self newWindow:self];
    
    return YES;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    DLog(@"openFile: %@", filename);
    BOOL isDir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDir];
    if (exists && isDir) {
        SearchQuery *q = [SearchQuery defaultQuery];
        q[@"volume"] = filename;
        [self newWindowWithQuery:q];
        return YES;
    }
    return NO;
}

// Handles multiple files dragged on app icon / opened at once
//- (void)application:(NSApplication *)theApplication openFiles:(NSArray *)filenames {
//    DLog(@"%@ dropped", [filenames description]);
//}

#pragma mark - Key/value observation

- (void)startObservingDefaults {
    NSArray *obsDef = @[@"StatusItemMode", @"GlobalShortcut", @"RememberRecentSearches"];
    for (NSString *def in obsDef) {
        [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
                                                                  forKeyPath:VALUES_KEYPATH(def)
                                                                     options:NSKeyValueObservingOptionNew
                                                                     context:NULL];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSString *def = [keyPath substringFromIndex:[@"values." length]];
    
    if ([def hasSuffix:@"StatusItemMode"]) {
        [self setAppMode:[DEFAULTS boolForKey:@"StatusItemMode"]];
    }
    else if ([def hasSuffix:@"GlobalShortcut"]) {
        // TODO: Set shortcut for menu items
    }
    else if ([def hasSuffix:@"RememberRecentSearches"]) {
        if (![DEFAULTS boolForKey:@"RememberRecentSearches"]) {
            // Purge search history
            [DEFAULTS setObject:@[] forKey:@"RecentSearches"];
            [DEFAULTS synchronize];
        }
    }
}

#pragma mark - App Mode

- (void)setAppMode:(BOOL)backgroundMode {
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    OSStatus returnCode = noErr;
    BOOL prefsVisible = [[prefsController window] isVisible];
    
    if (backgroundMode) {
        [self showStatusItem];
        returnCode = TransformProcessType(&psn, kProcessTransformToUIElementApplication);
        if (prefsVisible) {
            [self performSelector:@selector(showPreferences:) withObject:self afterDelay:0.25f];
        }        
    } else {
        [self hideStatusItem];
        returnCode = TransformProcessType(&psn, kProcessTransformToForegroundApplication);
        [NSApp activateIgnoringOtherApps:YES];
    }
    if (returnCode != noErr) {
        DLog(@"Failed to change application mode. Error %d", (int)returnCode);
    }
}

#pragma mark - Services

- (void)searchByName:(NSPasteboard *)pb userData:(NSString *)userData error:(NSString **)err {
    DLog(@"Received search by name request");
    [self newWindow:self];
    // TODO: Accept text string
}

- (void)searchFolder:(NSPasteboard *)pb userData:(NSString *)userData error:(NSString **)err {
    DLog(@"Received search in folder request");
    if (![[pb types] containsObject:NSFilenamesPboardType]) {
        return;
    }
    NSArray *files = [pb propertyListForType:NSFilenamesPboardType];
    if (![files count]) {
        return;
    }
    
    SearchQuery *q = [SearchQuery defaultQuery];
    q[@"volume"] = files[0];
    [self newWindowWithQuery:q];
}

#pragma mark - Authorization

- (BOOL)isAuthenticated {
    return (authorizationRef != NULL);
}

- (OSErr)authenticate {
    OSStatus err = noErr;
    const char *toolPath = [[[NSBundle mainBundle] pathForResource:@"searchfs" ofType:nil] fileSystemRepresentation];
    
    AuthorizationItem myItems = { kAuthorizationRightExecute, strlen(toolPath), &toolPath, 0 };
    AuthorizationRights myRights = { 1, &myItems };
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
    // Create authorization reference
    err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
    if (err != errAuthorizationSuccess) {
        authorizationRef = NULL;
        return err;
    }
    
    // Pre-authorize the privileged operation
    err = AuthorizationCopyRights(authorizationRef, &myRights, kAuthorizationEmptyEnvironment, flags, NULL);
    if (err != errAuthorizationSuccess) {
        authorizationRef = NULL;
        return err;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AUTHCHANGE_NOTIFICATION object:self];

    return noErr;
}

- (void)deauthenticate {
    // Destroy authorization reference
    if (authorizationRef) {
        AuthorizationFree(authorizationRef, kAuthorizationFlagDestroyRights);
        authorizationRef = NULL;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AUTHCHANGE_NOTIFICATION object:self];
}

- (AuthorizationRef)authorization {
    return authorizationRef;
}

- (void)authenticationStatusChanged {
    BOOL locked = ![self isAuthenticated];

    NSString *title = locked ? @"Authenticate" : @"Deauthenticate";
    SEL action = locked ? @selector(authenticate) : @selector(deauthenticate);
    NSImage *img = [NSImage imageNamed:(locked ? @"NSLockLockedTemplate" : @"NSLockUnlockedTemplate")];
//    [img setSize:NSMakeSize(9, 12)];
    
    [authenticateMenuItem setTitle:title];
    [authenticateMenuItem setAction:action];
    [authenticateMenuItem setTarget:self];
    [authenticateMenuItem setImage:img];
}

#pragma mark - Window controllers

- (void)newWindow:(id)sender {
    [self newWindowWithQuery:nil];
}

- (void)newWindowWithQuery:(SearchQuery *)query {
    [self animateStatusItem];
    [NSApp activateIgnoringOtherApps:YES];
    SearchController *controller = [SearchController newControllerWithSearchQuery:query];
    [windowControllers addObject:controller];
    [controller showWindow:self];
    [DEFAULTS setBool:YES forKey:@"PreviouslyLaunched"];
}

- (void)windowDidClose:(id)sender {
    [windowControllers removeObject:sender];
}

- (IBAction)showIntroWindow:(id)sender {
    if (introWindowController == nil) {
        introWindowController = [IntroController newController];
    }
    [introWindowController showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)showPreferences:(id)sender {
    if (prefsController == nil) {
        prefsController = [PrefsController new];
    }
    [prefsController showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

#pragma mark - Recent Searches

- (IBAction)openRecentSearch:(id)sender {
    SearchQuery *sq = [sender representedObject];
    if (sq) {
        SearchController *c = [SearchController newControllerWithSearchQuery:sq];
        [windowControllers addObject:c];
        [c showWindow:self];
    }
    else {
        DLog(@"No search query associated with item.");
    }
}

- (IBAction)clearRecentSearches:(id)sender {
    [DEFAULTS setObject:@[] forKey:@"RecentSearches"];
}

#pragma mark - Status Item

- (void)showStatusItem {
    // Create status item
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSImage *icon = [NSImage imageNamed:@"StatusItemIcon"];
    [icon setSize:NSMakeSize(16, 14)];
    [statusItem.button setImage:icon];
    
    // Behaviour can only be set on 10.12+
//    NSOperatingSystemVersion sysver = [[NSProcessInfo processInfo] operatingSystemVersion];
//    if (sysver.majorVersion > 10 || sysver.minorVersion >= 12) {
//        if (@available(macOS 10.12, *)) {
//            [statusItem setBehavior:NSStatusItemBehaviorRemovalAllowed|NSStatusItemBehaviorTerminationOnRemoval];
//        }
//    }
    
    // Duplicate main menu, insert it as submenu in the status item menu
    NSMenu *menuBar = [mainMenu copy];
    [menuBarItem setSubmenu:menuBar];
    
    // Enable Hide menu item
    NSMenu *appMenu = [[menuBar itemWithTitle:@"KatSearch"] submenu];
    NSMenuItem *hideMenuItem = [appMenu itemWithTitle:@"Hide KatSearch"];
    [hideMenuItem setAction:@selector(hideApp:)];
    [hideMenuItem setTarget:NSApp];
    [hideMenuItem setEnabled:YES];
    
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
    if (!statusItem) {
        return;
    }
    // Briefly highlight status item
    [statusItem.button setHighlighted:YES];
    id itemButton = statusItem.button;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.17 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [itemButton setHighlighted:NO];
    });
}

#pragma mark - NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu {
    if (menu == statusMenu) {
    }
    // Construct open recent menu
    else if (menu == openRecentMenu) {
        [menu removeAllItems];
        if ([DEFAULTS boolForKey:@"RememberRecentSearches"]) {
            // Construct menu with list of recent searches
            NSArray *recent = [DEFAULTS objectForKey:@"RecentSearches"];
            for (NSDictionary *d in recent) {
                SearchQuery *sq = [SearchQuery searchQueryFromDictionary:d];
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@""
                                                              action:@selector(openRecentSearch:)
                                                       keyEquivalent:@""];
                [item setRepresentedObject:sq];
                [item setAttributedTitle:[sq menuItemString]];
//                NSImage *img = [NSImage imageNamed:@"NSGenericDocument"];
//                [img setSize:NSMakeSize(16,16)];
//                [item setImage:img];
                [menu addItem:item];
            }
        }
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:@"Clear Menu" action:@selector(clearRecentSearches:) keyEquivalent: @""];
    }
}

// Open Documentation.html file within app bundle
- (IBAction)showHelp:(id)sender {
    NSString *path = [[NSBundle mainBundle] pathForResource:PROGRAM_DOCUMENTATION_FILE ofType:nil];
    [[NSWorkspace sharedWorkspace] openPathInDefaultBrowser:path];
}

// Open donations website
- (IBAction)openDonations:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PROGRAM_DONATIONS_URL]];
}

// Open program website
- (IBAction)openWebsite:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PROGRAM_WEBSITE_URL]];
}

// Open program GitHub website
- (IBAction)openGitHubWebsite:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PROGRAM_GITHUB_URL]];
}

// Open License HTML file
- (IBAction)openLicense:(id)sender {
    NSString *path = [[NSBundle mainBundle] pathForResource:PROGRAM_LICENSE_FILE ofType:nil];
    [[NSWorkspace sharedWorkspace] openPathInDefaultBrowser:path];
}

// Open HTML version of command line tool man page
- (IBAction)openCommandLineToolManPage:(id)sender {
    NSString *path = [[NSBundle mainBundle] pathForResource:PROGRAM_MAN_PAGE_FILE ofType:nil];
    [[NSWorkspace sharedWorkspace] openPathInDefaultBrowser:path];
}

@end
