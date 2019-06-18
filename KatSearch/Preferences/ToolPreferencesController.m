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

#import "ToolPreferencesController.h"
#import "Common.h"

@interface ToolPreferencesController()
{
    IBOutlet NSImageView *execImageView;
    IBOutlet NSTextField *statusTextField;
    IBOutlet NSButton *installButton;
    IBOutlet NSProgressIndicator *progressIndicator;
}
@end

@implementation ToolPreferencesController

#pragma mark -

- (id)init {
    return [super initWithNibName:@"ToolPreferencesView" bundle:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear {
    [self updateInstallStatusMessage];
}

- (void)updateInstallStatusMessage {
    if ([self isInstalled]) {
        [execImageView setAlphaValue:1.0f];
        [statusTextField setStringValue:@"Command line tool is installed"];
        [installButton setTitle:@"Uninstall"];
    } else {
        [execImageView setAlphaValue:0.3f];
        [statusTextField setStringValue:@"Command line tool is not installed"];
        [installButton setTitle:@"Install “searchfs” tool"];
    }
}

- (IBAction)buttonPressed:(id)sender {
    [progressIndicator setUsesThreadedAnimation:YES];
    [progressIndicator startAnimation:self];
    
    if ([self isInstalled]) {
        [self uninstallTool];
    } else {
        [self installTool];
    }
    [self performSelector:@selector(updateInstallStatusMessage) withObject:nil afterDelay:0.5f];
    [progressIndicator performSelector:@selector(stopAnimation:) withObject:self afterDelay:0.5f];
}

#pragma mark - Install/Uninstall

- (BOOL)installTool {
    NSString *binPath = [[NSBundle mainBundle] pathForResource:CLT_BIN_NAME ofType:nil];
    int res = [[NSFileManager defaultManager] copyItemAtPath:binPath
                                                      toPath:CLT_INSTALL_PATH
                                                       error:nil];
    NSString *manPath = [[NSBundle mainBundle] pathForResource:CLT_MAN_NAME ofType:nil];
    res += [[NSFileManager defaultManager] copyItemAtPath:manPath
                                                   toPath:CLT_MAN_INSTALL_PATH
                                                    error:nil];
    return (res == 2);
}

- (BOOL)uninstallTool {
    int res = [[NSFileManager defaultManager] removeItemAtPath:CLT_INSTALL_PATH error:nil];
    res += [[NSFileManager defaultManager] removeItemAtPath:CLT_MAN_INSTALL_PATH error:nil];
    return (res == 2);
}

- (BOOL)isInstalled {
    return [[NSFileManager defaultManager] fileExistsAtPath:CLT_INSTALL_PATH] &&
    [[NSFileManager defaultManager] fileExistsAtPath:CLT_MAN_INSTALL_PATH];
}

#pragma mark - MASPreferencesViewController

- (NSString *)viewIdentifier {
    return @"ToolPreferences";
}

- (NSImage *)toolbarItemImage {
    return [NSImage imageNamed:@"CommandLineTool"];
}

- (NSString *)toolbarItemLabel {
    return @"Tool";
}

//- (NSView *)initialKeyView {
//    return nil;
//}

- (BOOL)hasResizableWidth {
    return NO;
}

- (BOOL)hasResizableHeight {
    return NO;
}

@end
