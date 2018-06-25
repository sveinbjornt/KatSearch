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

#import "SearchItem.h"
#import "NSWorkspace+Additions.h"
#include <sys/stat.h>

@implementation SearchItem
{
    NSString *cachedKindString;
    NSString *cachedSizeString;
    NSString *cachedDateModifiedString;
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _path = path;
        _name = [path lastPathComponent];
        _icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
    }
    return self;
}

- (NSString *)sizeString {
    if (_sizeString) {
        return _sizeString;
    }
    
    UInt64 size = self.size;
    if (size == -1) {
        _sizeString = @"-";
    } else {
        _sizeString = [self fileSizeAsHumanReadableString:size];
    }
    
    return _sizeString;
}

- (NSString *)kind {
    
    if (!cachedKindString) {
        CFStringRef kindCFStr = nil;
        LSCopyKindStringForURL((__bridge CFURLRef)[NSURL fileURLWithPath:self.path], &kindCFStr);
        if (kindCFStr) {
            cachedKindString = [NSString stringWithString:(__bridge NSString *)kindCFStr];
            CFRelease(kindCFStr);
        } else {
            cachedKindString = @"Unknown";
        }
    }
    
    return cachedKindString;
}

- (void)stat {
    
}

- (UInt64)size {
//    BOOL isDir;
    NSString *p = self.path;
//    [[NSFileManager defaultManager] fileExistsAtPath:p isDirectory:&isDir];
//    if (isDir) {
//        return 0;
//    }
    
    
    
    struct stat stat1;
    if (stat([p fileSystemRepresentation], &stat1)) {
        return -1;
    }
    
    if (!S_ISREG(stat1.st_mode)) {
        return -1;
    }
    
    return stat1.st_size;
}

- (NSString *)fileSizeAsHumanReadableString:(UInt64)size {
    NSString *str;
    
    if (size < 1024ULL) {
        str = [NSString stringWithFormat:@"%u bytes", (unsigned int)size];
    } else if (size < 1048576ULL) {
        str = [NSString stringWithFormat:@"%llu KB", (UInt64)size / 1024];
    } else if (size < 1073741824ULL) {
        str = [NSString stringWithFormat:@"%.1f MB", size / 1048576.0];
    } else {
        str = [NSString stringWithFormat:@"%.1f GB", size / 1073741824.0];
    }
    return str;
}

- (void)open {
    [[NSWorkspace sharedWorkspace] openFile:self.path];
}

- (void)openWith:(NSString *)appIdentifier {
    [[NSWorkspace sharedWorkspace] openFile:self.path withApplication:appIdentifier];
}

- (void)showInFinder {
    [[NSWorkspace sharedWorkspace] selectFile:self.path
                     inFileViewerRootedAtPath:[self.path stringByDeletingLastPathComponent]];
}

- (void)getInfo {
    [[NSWorkspace sharedWorkspace] showFinderGetInfoForFile:self.path];
}

- (void)quickLook {
    [[NSWorkspace sharedWorkspace] quickLookFile:self.path];
}

- (NSArray *)handlerApplications {
    return [[NSWorkspace sharedWorkspace] applicationsForFile:self.path];

}

- (NSString *)defaultHandlerApplication {
    return [[NSWorkspace sharedWorkspace] defaultApplicationForFile:self.path];
}

#pragma mark -

- (NSString *)description {
    return self.path;
}

@end
