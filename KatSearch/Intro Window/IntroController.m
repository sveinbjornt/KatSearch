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

#import "IntroController.h"
#import <MASShortcut/Shortcut.h>
#import "AppDelegate.h"
#import "SDOpenAtLogin.h"
#import "Common.h"

@interface IntroController ()
{
    IBOutlet NSBox *firstBox;
    IBOutlet NSBox *secondBox;
    
    IBOutlet NSButton *backButton;
    IBOutlet NSButton *continueButton;
    
    IBOutlet SelectableImageView *appModeImageView;
    IBOutlet SelectableImageView *statusItemModeImageView;
    
    IBOutlet MASShortcutView *shortcutView;
    
    NSRect zeroFrame;
    NSRect firstFrame;
    NSRect secondFrame;
}
@end

@implementation IntroController

+ (instancetype)newController {
    return [[self alloc] initWithWindowNibName:@"IntroWindow"];
}

#pragma mark -

- (void)windowDidLoad {
    [super windowDidLoad];
    
    zeroFrame = CGRectOffset(firstBox.frame, -firstBox.frame.size.width, 0);
    firstFrame = firstBox.frame;
    secondFrame = secondBox.frame;
    
    statusItemModeImageView.selected = YES;
    
    [shortcutView setAssociatedUserDefaultsKey:@"GlobalShortcut"];
    
    [DEFAULTS setBool:YES forKey:@"SUEnableAutomaticChecks"];
    
    [[self window] center];
    [[self window] makeKeyAndOrderFront:self];
}

#pragma mark - SelectableImageViewDelegate

- (IBAction)imageViewClicked:(id)sender {
    [appModeImageView setSelected:NO];
    [statusItemModeImageView setSelected:NO];
    [sender setSelected:YES];
}

- (IBAction)next:(id)sender {
    if ([[sender title] hasPrefix:@"Continue"]) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.4f;
            self->firstBox.animator.frame = self->zeroFrame;
            self->secondBox.animator.frame = self->firstFrame;
            self->backButton.hidden = NO;
            self->continueButton.title = @"Start using KatSearch";
        } completionHandler:nil];
    } else {
        // Start using KatSearch...
        [self start:sender];
    }
}

- (IBAction)back:(id)sender {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.4f;
        self->firstBox.animator.frame = self->firstFrame;
        self->secondBox.animator.frame = self->secondFrame;
        self->backButton.hidden = YES;
        self->continueButton.title = @"Continue →";
    } completionHandler:nil];
}

- (IBAction)start:(id)sender {
    AppDelegate *delegate = (AppDelegate *)[NSApp delegate];

    if (shortcutView.shortcutValue) {
        // Set shortcut
    }
    
    if ([DEFAULTS boolForKey:@"LaunchAtLogin"]) {
        [SDOpenAtLogin setOpensAtLogin:YES];
    }
    
    [[self window] close];
    
    // Apply settings specified during the setup process
    if (statusItemModeImageView.selected) {
        // Transition to status item mode
        [delegate setAppMode:YES];
    }
    
    // Open new search window
    [delegate performSelector:@selector(newWindow:) withObject:self afterDelay:0.25];
}

@end
