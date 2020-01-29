/*
    Copyright (c) 2018-2020, Sveinbjorn Thordarson <sveinbjorn@sveinbjorn.org>
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
    // Application window controllers
    NSMutableArray *searchWindowControllers;
    MASPreferencesWindowController *prefsController;
    IntroController *introWindowController;
    
    IBOutlet NSMenu *mainMenu;
    IBOutlet NSMenu *openRecentMenu;
    IBOutlet NSMenu *statusItemOpenRecentMenu;
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
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Application setup
    
    // First, transition from LSUIElement (default) to regular app if needed
    [self setAppMode:[DEFAULTS boolForKey:@"StatusItemMode"]];
    
    // Associate the shortcut hotkey combo with a new window / bring to front action
    NSMutableArray *wc = [NSMutableArray new];
    searchWindowControllers = wc;
    [[MASShortcutBinder sharedBinder] bindShortcutWithDefaultsKey:SHORTCUT_DEFAULT_NAME
                                                         toAction:^{
         if ([NSApp isActive] || ![wc count]) {
             [self newWindow:self];
         }
     }];
    
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
    // Called when application dock icon is clicked
    if (flag) {
        return NO;
    }
    [self newWindow:self];
    
    return YES;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    // Open file handler
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

#pragma mark - App Mode

- (void)setAppMode:(BOOL)backgroundMode {
    // Transition between foreground and background (LSUIElement) mode
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

#pragma mark - Key/value observation

- (void)startObservingDefaults {
    // Watch for changes to these defaults
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

#pragma mark - Services

- (void)searchByName:(NSPasteboard *)pb userData:(NSString *)userData error:(NSString **)err {
    DLog(@"Received search by name service request");
    [self newWindow:self];
    // TODO: Accept text string
}

- (void)searchFolder:(NSPasteboard *)pb userData:(NSString *)userData error:(NSString **)err {
    DLog(@"Received search in folder service request");
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
    // Create and store an authorization reference
    OSStatus err = noErr;
    const char *toolPath = [[[NSBundle mainBundle] pathForResource:@"searchfs" ofType:nil] fileSystemRepresentation];
    
    // TODO: Tool path is variable, how does that work?
    AuthorizationItem myItems = { kAuthorizationRightExecute, strlen(toolPath), &toolPath, 0 };
    AuthorizationRights myRights = { 1, &myItems };
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
    // Create auth ref
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

- (void)authenticationStatusChanged {
    BOOL locked = ![self isAuthenticated];

    NSString *title = locked ? @"Authenticate" : @"Deauthenticate";
    SEL action = locked ? @selector(authenticate) : @selector(deauthenticate);
    NSImage *img = [NSImage imageNamed:(locked ? @"NSLockLockedTemplate" : @"NSLockUnlockedTemplate")];
    
    [authenticateMenuItem setTitle:title];
    [authenticateMenuItem setAction:action];
    [authenticateMenuItem setTarget:self];
    [authenticateMenuItem setImage:img];
}

- (AuthorizationRef)authorization {
    return authorizationRef;
}

#pragma mark - Window controllers

- (void)newWindow:(id)sender {
    [self newWindowWithQuery:nil];
}

- (void)newWindowWithQuery:(SearchQuery *)query {
    [self animateStatusItem];
    [NSApp activateIgnoringOtherApps:YES];
    
    SearchController *controller = [SearchController newControllerWithSearchQuery:query];
    [controller showWindow:self];
    [searchWindowControllers addObject:controller];
    
    [DEFAULTS setBool:YES forKey:@"PreviouslyLaunched"];
}

- (void)windowDidClose:(id)sender {
    // Called by SearchController when search window is closed
    [searchWindowControllers removeObject:sender];
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
    id query = [sender representedObject];
    if ([query isKindOfClass:[SearchQuery class]]) {
        [self newWindowWithQuery:query];
    } else {
        DLog(@"No search query associated with sender.");
    }
}

- (IBAction)clearRecentSearches:(id)sender {
    [DEFAULTS setObject:@[] forKey:@"RecentSearches"];
}

- (void)constructOpenRecentMenu:(NSMenu *)menu {
    // Construct menu with list of recent searches
    [menu removeAllItems];
    if ([DEFAULTS boolForKey:@"RememberRecentSearches"]) {
        NSArray *recent = [DEFAULTS objectForKey:@"RecentSearches"];
        for (NSDictionary *d in recent) {
            SearchQuery *sq = [SearchQuery searchQueryFromDictionary:d];
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@""
                                                          action:@selector(openRecentSearch:)
                                                   keyEquivalent:@""];
            [item setRepresentedObject:sq];
            [item setAttributedTitle:[sq menuItemString]];
            [menu addItem:item];
        }
    }
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Clear Menu" action:@selector(clearRecentSearches:) keyEquivalent: @""];
}

#pragma mark - Status Item

- (void)showStatusItem {
    // Create status item
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSImage *icon = [NSImage imageNamed:@"StatusItemIcon"];
    [icon setSize:NSMakeSize(16, 14)];
    [statusItem.button setImage:icon];
    
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
    // Dynamically construct open recent menu
    if (menu == openRecentMenu || menu == statusItemOpenRecentMenu) {
        [self constructOpenRecentMenu:menu];
    }
}

#pragma mark - Menu actions

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
