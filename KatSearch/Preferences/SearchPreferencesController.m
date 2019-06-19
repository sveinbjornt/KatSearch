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

#import "SearchPreferencesController.h"
#import "SearchTargetPopupButton.h"
#import "Common.h"

@interface SearchPreferencesController ()
{
    IBOutlet SearchTargetPopupButton *volumesPopupButton;
}
@end

@implementation SearchPreferencesController

#pragma mark -

- (id)init {
    return [super initWithNibName:@"SearchPreferencesView" bundle:nil];
}

- (void)viewDidLoad {
    [volumesPopupButton selectPath:[DEFAULTS stringForKey:@"FindOnVolume"]];
}

- (IBAction)defaultVolumeChanged:(id)sender {
    [DEFAULTS setObject:[volumesPopupButton pathOfSelectedItem] forKey:@"FindOnVolume"];
}

#pragma mark - MASPreferencesViewController

- (NSString *)viewIdentifier {
    return @"SearchPreferences";
}

- (NSImage *)toolbarItemImage {
    return [NSImage imageNamed:@"SearchCatIcon"];
}

- (NSString *)toolbarItemLabel {
    return @"Search";
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
