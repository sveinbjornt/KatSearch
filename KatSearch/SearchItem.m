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

#import "SearchItem.h"
#import "NSWorkspace+Additions.h"
#import "DateFormatter.h"
#include <sys/stat.h>
#include <pwd.h>
#include <grp.h>

@implementation SearchItem
{
    NSString *cachedName;
    
    NSImage *cachedIcon;
    
    NSString *cachedKindString;
    
    NSString *cachedHFSType;
    NSString *cachedCreatorType;
    
    NSString *cachedMIMEType;
    
    NSString *cachedSizeString;
    
    NSDate *cachedDateAccessed;
    NSString *cachedDateAccessedString;
    
    NSDate *cachedDateCreated;
    NSString *cachedDateCreatedString;
    
    NSDate *cachedDateModified;
    NSString *cachedDateModifiedString;
    
    NSString *cachedUTI;
    
    NSString *cachedUser;
    NSString *cachedGroup;
    NSString *cachedUserGroupString;
    
    NSString *cachedPermissionsString;
    
    NSURL *cachedURL;
    
    int bookmark;
    
    struct stat cachedStat;
    struct stat *cachedStatPtr;
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _path = path;
        bookmark = -1; // Unknown
    }
    return self;
}

// This method primes the item's caching mechanism
// by running stat and generating strings for display
- (void)prime {
    [self name];
    [self url];
    [self icon];
    [self sizeString];
    [self kind];
    [self dateModifiedString];
    // TODO: Prime according to visible columns
}

#pragma mark - Attributes

- (NSString *)name {
    if (!cachedName) {
        cachedName = [self.path lastPathComponent];
    }
    return cachedName;
}

- (NSURL *)url {
    if (!cachedURL) {
        cachedURL = [NSURL fileURLWithPath:self.path];
    }
    return cachedURL;
}

- (NSImage *)icon {
    if (!cachedIcon) {
        cachedIcon = [[NSWorkspace sharedWorkspace] iconForFile:self.path];
    }
    return cachedIcon;
}

- (NSString *)sizeString {
    if (!cachedSizeString) {
        UInt64 size = self.size;
        if (size == -1) {
            cachedSizeString = @"-";
        } else {
            cachedSizeString = [[NSWorkspace sharedWorkspace] fileSizeAsHumanReadableString:size];
        }
    }
    
    return cachedSizeString;
}

- (NSString *)kind {
    if (!cachedKindString) {
        NSString *kindStr = nil;
        
        if ([self isSymlink]) {
            kindStr = @"Symbolic Link";
        } else {
            [self.url getResourceValue:&kindStr forKey:NSURLLocalizedTypeDescriptionKey error:nil];
        }
        cachedKindString = kindStr ? kindStr : SI_UNKNOWN;
    }
    
    return cachedKindString;
}

- (NSString *)HFSType {
    if (!cachedHFSType) {
        [self getLegacyFileAndCreatorTypes];
    }
    return cachedHFSType;
}

- (void)getLegacyFileAndCreatorTypes {
    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:self.path error:nil];
    if (attr) {
        OSType hfsType = [attr fileHFSTypeCode];
        if (hfsType) {
            cachedHFSType = (__bridge NSString *)UTCreateStringForOSType(hfsType);
        }
        OSType ccType = [attr fileHFSCreatorCode];
        if (ccType) {
            cachedCreatorType = (__bridge NSString *)UTCreateStringForOSType(ccType);
        }
    }
    cachedHFSType = cachedHFSType ? cachedHFSType : @"";
    cachedCreatorType = cachedCreatorType ? cachedCreatorType : @"";
}

- (NSString *)creatorType {
    if (!cachedCreatorType) {
        [self getLegacyFileAndCreatorTypes];
    }
    return cachedCreatorType;
}

- (NSString *)MIMEType {
    if (!cachedMIMEType) {
        CFStringRef mType = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)[self UTI], kUTTagClassMIMEType);
        cachedMIMEType = mType ? (__bridge_transfer NSString *)mType : @"";
    }
    return cachedMIMEType;
}

- (BOOL)stat {
    if (cachedStatPtr) {
        return YES;
    }
//    NSLog(@"Stat");

    if (lstat([self.path fileSystemRepresentation], &cachedStat)) {
        NSLog(@"Stat failed: %@", self.description);
        return NO;
    }
    
    cachedStatPtr = &cachedStat;
    
    return YES;
}

- (NSDate *)dateAccessed {
    if (![self stat]) {
        return nil;
    }
    return [NSDate dateWithTimeIntervalSince1970:cachedStatPtr->st_atimespec.tv_sec];
}

- (NSString *)dateAccessedString {
    if (![self stat]) {
        return SI_UNKNOWN;
    }
    
    if (!cachedDateAccessedString) {
        cachedDateAccessedString = [self relativeDateStringForTimestamp:cachedStatPtr->st_atimespec.tv_sec];
    }
    
    return cachedDateAccessedString;
}

- (NSDate *)dateCreated {
    if (![self stat]) {
        return nil;
    }
    return [NSDate dateWithTimeIntervalSince1970:cachedStatPtr->st_ctimespec.tv_sec];
}

- (NSString *)dateCreatedString {
    if (![self stat]) {
        return SI_UNKNOWN;
    }
    
    if (!cachedDateCreatedString) {
        cachedDateCreatedString = [self relativeDateStringForTimestamp:cachedStatPtr->st_ctimespec.tv_sec];
    }
    
    return cachedDateCreatedString;
}

- (NSDate *)dateModified {
    if (![self stat]) {
        return nil;
    }
    return [NSDate dateWithTimeIntervalSince1970:cachedStatPtr->st_mtimespec.tv_sec];
}

- (NSString *)dateModifiedString {
    if (![self stat]) {
        return SI_UNKNOWN;
    }
    
    if (!cachedDateModifiedString) {
        cachedDateModifiedString = [self relativeDateStringForTimestamp:cachedStatPtr->st_mtimespec.tv_sec];
    }
    
    return cachedDateModifiedString;
}

- (NSString *)relativeDateStringForTimestamp:(__darwin_time_t)time {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:time];
    return [[DateFormatter formatter] stringFromDate:date];
}

- (NSString *)user {
    if (![self stat]) {
        return SI_UNKNOWN;
    }
    
    if (!cachedUser) {
        const char *u = user_from_uid(cachedStatPtr->st_uid, 1);
        cachedUser = u ? @(u) : SI_UNKNOWN;
    }
    return cachedUser;
}

- (NSString *)group {
    if (![self stat]) {
        return SI_UNKNOWN;
    }
    
    if (!cachedGroup) {
        const char *g = group_from_gid(cachedStatPtr->st_gid, 1);
        cachedGroup = g ? @(g) : SI_UNKNOWN;
    }
    
    return cachedGroup;
}

- (NSString *)userGroupString {
    if (!cachedUserGroupString) {
        cachedUserGroupString = [NSString stringWithFormat:@"%@:%@", [self user], [self group]];
    }
    return cachedUserGroupString;
}

- (NSString *)permissionsString {
    if (![self stat]) {
        return SI_UNKNOWN;
    }
    
    if (!cachedPermissionsString) {
        char buf[20];
//        NSLog(@"%07o", cachedStatPtr->st_mode);
        strmode(cachedStatPtr->st_mode, (char *)&buf);
        cachedPermissionsString = @((char *)&buf);
    }
    
    return cachedPermissionsString;
}

- (UInt64)size {
    if ([self stat] && S_ISREG(cachedStat.st_mode)) {
        return cachedStatPtr->st_size;
    }
    return -1;
}

- (NSString *)UTI {
    if (cachedUTI) {
        return cachedUTI;
    }
    if ([self isSymlink]) {
        cachedUTI = (NSString *)kUTTypeSymLink; // or kUTTypeAliasFile ???
    } else {
        NSString *type = [[NSWorkspace sharedWorkspace] typeOfFile:self.path error:nil];
        cachedUTI = (type == nil) ? SI_UNKNOWN : type;
    }
    return cachedUTI;
}

- (BOOL)isBookmark {
    if (bookmark == -1) { // Indeterminate
        NSNumber *number = nil;
        [self.url getResourceValue:&number
                            forKey:NSURLIsAliasFileKey
                             error:nil];
        bookmark = [number boolValue];
    }
    return bookmark;
}

- (BOOL)isSymlink {
    if (![self stat]) {
        return NO;
    }
    return S_ISLNK(cachedStatPtr->st_mode);
}

- (BOOL)isDirectory {
    if (![self stat]) {
        return NO;
    }
    return S_ISDIR(cachedStatPtr->st_mode);
}

#pragma mark - Handler apps

- (NSString *)defaultHandlerApplication {
    return [[NSWorkspace sharedWorkspace] defaultApplicationForFile:self.path];
}

- (NSArray *)handlerApplications {
    return [[NSWorkspace sharedWorkspace] applicationsForFile:self.path];
}

#pragma mark - Actions

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

- (void)showOriginal {
    if ([self isBookmark]) {
        [[NSWorkspace sharedWorkspace] showOriginal:self.path];
    } else {
        NSBeep();
    }
}

- (void)getInfo {
    [[NSWorkspace sharedWorkspace] showFinderGetInfoForFile:self.path];
}

- (void)quickLook {
    [[NSWorkspace sharedWorkspace] quickLookFile:self.path];
}

#pragma mark -

- (NSString *)description {
    return self.path;
}

@end
