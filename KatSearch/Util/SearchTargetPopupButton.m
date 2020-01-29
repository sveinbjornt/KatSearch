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

#import "SearchTargetPopupButton.h"

#include <sys/attr.h>
#include <sys/param.h>
#include <sys/attr.h>
#include <sys/vnode.h>
#include <sys/fsgetpath.h>
#include <sys/mount.h>

@implementation SearchTargetPopupButton

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    
    [[self menu] setDelegate:self];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector: @selector(volumesChanged:) name:NSWorkspaceDidMountNotification object: nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector: @selector(volumesChanged:) name:NSWorkspaceDidUnmountNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector: @selector(volumesChanged:) name:NSWorkspaceDidRenameVolumeNotification object:nil];
    
    [self populateMenu];
}

- (void)dealloc {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (void)menuWillOpen:(NSMenu *)menu {
    [self populateMenu];
}

- (BOOL)selectItemWithToolTip:(NSString *)tt {
    for (NSMenuItem *item in [[self menu] itemArray]) {
        if ([[item toolTip] isEqualToString:tt]) {
            [self selectItem:item];
            return YES;
        }
    }
    return NO;
}

- (NSString *)pathOfSelectedItem {
    return [[self selectedItem] toolTip];
}

- (void)selectPath:(NSString *)path {
    BOOL sel = [self selectItemWithToolTip:path];
    if (!sel) {
        NSArray *recent = [[NSUserDefaults standardUserDefaults] objectForKey:@"RecentFolders"];
        if (recent == nil) {
            recent = [NSArray new];
        }
        
        // Add it to recent folders and save to defaults
        NSMutableArray *folders = [recent mutableCopy];
        [folders addObject:path];
        [[NSUserDefaults standardUserDefaults] setObject:[folders copy] forKey:@"RecentFolders"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [self populateMenu];
        [self selectItemWithToolTip:path];
    }
}

- (void)volumesChanged:(NSNotification *)notification {
    [self populateMenu];
}

- (void)populateMenu {
    NSMenu *volumesMenu = [self menu];
    
    // Get currently selected volume
    NSMenuItem *selectedItem = [self selectedItem];
    NSString *selectedPath = [selectedItem toolTip];
    
    // Rebuild menu
    [volumesMenu removeAllItems];
    
    NSArray *props = @[NSURLVolumeNameKey];
    NSArray *urls = [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:props options:NSVolumeEnumerationSkipHiddenVolumes];
    
    // Add all volumes as menu items
    for (NSURL *url in urls) {
        
        if (self.searchfsCapableVolumesOnly && ![self volumeIsSearchFSCapable:url.path]) {
            continue;
        }
        
        NSString *volumeName;
        [url getResourceValue:&volumeName forKey:NSURLVolumeNameKey error:nil];
        
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:volumeName
                                                      action:nil
                                               keyEquivalent:@""];
        [item setTarget:self];
        [item setToolTip:[url path]];
        
        NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
        [icon setSize:NSMakeSize(16, 16)];
        [item setImage:icon];
        
        [volumesMenu addItem:item];
    }
    
    // Separator
    [volumesMenu addItem:[NSMenuItem separatorItem]];
    
    // Create recent folders list in defaults, if it doesn't exist
    NSArray *recent = [[NSUserDefaults standardUserDefaults] objectForKey:@"RecentFolders"];
    if (recent == nil) {
        recent = [NSArray new];
        [[NSUserDefaults standardUserDefaults] setObject:recent forKey:@"RecentFolders"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    // Always include home folder
    NSMutableArray *folders = [recent mutableCopy];
    [folders insertObject:NSHomeDirectory() atIndex:0];
    // Add all folders as menu items
    for (NSString *path in folders) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[path lastPathComponent]
                                                      action:nil
                                               keyEquivalent:@""];
        [item setTarget:self];
        [item setToolTip:path];
        
        NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
        [icon setSize:NSMakeSize(16, 16)];
        [item setImage:icon];
        
        // Make the folder name red if it no longer exists at path
        BOOL isDir;
        if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || !isDir) {
            NSDictionary *attrs = @{ NSForegroundColorAttributeName: [NSColor redColor] };
            NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:[path lastPathComponent]
                                                                          attributes:attrs];
            [item setAttributedTitle:attrStr];
            NSImage *qmarkIcon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kQuestionMarkIcon)];
            [qmarkIcon setSize:NSMakeSize(16, 16)];
            [item setImage:qmarkIcon];
        }
        
        [volumesMenu addItem:item];
    }
    
    // Now, restore selection, if possible
    if ([[volumesMenu itemArray] count] == 0) {
        return;
    }
    NSMenuItem *itemToSelect = [volumesMenu itemArray][0];
    for (NSMenuItem *item in [volumesMenu itemArray]) {
        if ([[item toolTip] isEqualToString:selectedPath]) {
            itemToSelect = item;
            break;
        }
    }
    [self selectItem:itemToSelect];
}

- (BOOL)volumeIsSearchFSCapable:(NSString *)volPath {
    
    struct vol_attr_buf {
        u_int32_t               size;
        vol_capabilities_attr_t vol_capabilities;
    } __attribute__((aligned(4), packed));
    
    const char *p = [volPath fileSystemRepresentation];
    
    struct attrlist attrList;
    memset(&attrList, 0, sizeof(attrList));
    attrList.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrList.volattr = (ATTR_VOL_INFO | ATTR_VOL_CAPABILITIES);
    
    struct vol_attr_buf attrBuf;
    memset(&attrBuf, 0, sizeof(attrBuf));
    
    int err = getattrlist(p, &attrList, &attrBuf, sizeof(attrBuf), 0);
    if (err != 0) {
        err = errno;
        fprintf(stderr, "Error %d getting attrs for volume %s", err, p);
        return NO;
    }
    
    assert(attrBuf.size == sizeof(attrBuf));
    
    if ((attrBuf.vol_capabilities.valid[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_SEARCHFS) == VOL_CAP_INT_SEARCHFS) {
        if ((attrBuf.vol_capabilities.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_SEARCHFS) == VOL_CAP_INT_SEARCHFS) {
            return YES;
        }
    }
    
    return NO;
}

@end
