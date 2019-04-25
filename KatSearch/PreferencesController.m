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
#import "PreferencesController.h"
#import "SDOpenAtLogin.h"
#import <MASShortcut/Shortcut.h>


@interface PreferencesController ()
@property (nonatomic, weak) IBOutlet MASShortcutView *shortcutView;
@end


@implementation PreferencesController

- (void)windowDidLoad {
    [super windowDidLoad];
    NSImage *img = [NSImage imageNamed:NSImageNamePreferencesGeneral];
    if (img) {
        [self.window setRepresentedURL:[NSURL URLWithString:@""]]; // Not representing a URL
        [[self.window standardWindowButton:NSWindowDocumentIconButton] setImage:img];
    }
    
    // Associate the shortcut view with user defaults
    self.shortcutView.associatedUserDefaultsKey = @"GlobalShortcut";
}

- (BOOL)window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu *)menu {
    // Prevent popup menu when window icon/title is cmd-clicked
    return NO;
}

- (BOOL)window:(NSWindow *)window shouldDragDocumentWithEvent:(NSEvent *)event from:(NSPoint)dragImageLocation withPasteboard:(NSPasteboard *)pasteboard {
    // Prevent dragging of title bar icon
    return NO;
}

- (IBAction)restoreDefaults:(id)sender {
    NSString *defPath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
    NSDictionary *def = [NSDictionary dictionaryWithContentsOfFile:defPath];
    for (NSString *key in def) {
        [DEFAULTS setObject:def[key] forKey:key];
    }
    [DEFAULTS synchronize];
}

- (IBAction)toggleLaunchAtLogin:(id)sender {
    [SDOpenAtLogin setOpensAtLogin:[DEFAULTS boolForKey:@"LaunchAtLogin"]];
}

@end
