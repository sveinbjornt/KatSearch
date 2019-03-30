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
#include <sys/stat.h>
#include <pwd.h>
#include <grp.h>


@implementation SearchItem
{
    NSString *cachedName;
    NSImage *cachedIcon;
    NSString *cachedKindString;
    NSString *cachedSizeString;
    NSString *cachedDateAccessedString;
    NSString *cachedDateCreatedString;
    NSString *cachedDateModifiedString;
    NSString *cachedUTI;
    NSString *cachedOwner;
    NSString *cachedGroup;
    NSString *cachedPermissionsString;
    
    struct stat cachedStat;
    struct stat *cachedStatPtr;
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _path = path;
    }
    return self;
}

#pragma mark - Attributes

- (NSString *)name {
    if (!cachedName) {
        cachedName = [_path lastPathComponent];
    }
    return cachedName;
}

- (NSImage *)icon {
    if (!cachedIcon) {
        cachedIcon = [[NSWorkspace sharedWorkspace] iconForFile:_path];
    }
    return cachedIcon;
}

- (NSString *)sizeString {
    if (cachedSizeString) {
        return cachedSizeString;
    }
    
    UInt64 size = self.size;
    if (size == -1) {
        cachedSizeString = @"-";
    } else {
        cachedSizeString = [[NSWorkspace sharedWorkspace] fileSizeAsHumanReadableString:size];
    }
    
    return cachedSizeString;
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

- (BOOL)stat {
    if (cachedStatPtr) {
        return YES;
    }
    
    if (stat([self.path fileSystemRepresentation], &cachedStat)) {
        return NO;
    }
    
    cachedStatPtr = &cachedStat;
    
    return YES;
}

- (NSDate *)dateAccessed {
    return [NSDate dateWithTimeIntervalSince1970:cachedStatPtr->st_atimespec.tv_sec];
}

- (NSString *)dateAccessedString {
    if (![self stat]) {
        return @"?";
    }
    
    if (!cachedDateAccessedString) {
        cachedDateAccessedString = [self relativeDateStringForTimestamp:cachedStatPtr->st_atimespec.tv_sec];
    }
    
    return cachedDateAccessedString;
}

- (NSDate *)dateCreated {
    return [NSDate dateWithTimeIntervalSince1970:cachedStatPtr->st_ctimespec.tv_sec];
}

- (NSString *)dateCreatedString {
    if (![self stat]) {
        return @"?";
    }
    
    if (!cachedDateCreatedString) {
        cachedDateCreatedString = [self relativeDateStringForTimestamp:cachedStatPtr->st_ctimespec.tv_sec];
    }
    
    return cachedDateCreatedString;
}

- (NSDate *)dateModified {
    return [NSDate dateWithTimeIntervalSince1970:cachedStatPtr->st_mtimespec.tv_sec];
}

- (NSString *)dateModifiedString {
    if (![self stat]) {
        return @"?";
    }
    
    if (!cachedDateModifiedString) {
        cachedDateModifiedString = [self relativeDateStringForTimestamp:cachedStatPtr->st_mtimespec.tv_sec];
    }
    
    return cachedDateModifiedString;
}

- (NSString *)relativeDateStringForTimestamp:(__darwin_time_t)time {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:time];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.doesRelativeDateFormatting = YES;
    formatter.locale = [NSLocale currentLocale];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:date];
}

- (NSString *)owner {
    if (![self stat]) {
        return nil;
    }
    
    if (!cachedOwner) {
        const char *u = user_from_uid(cachedStatPtr->st_uid, 0);
        cachedOwner = @(u);
    }
    
    return cachedOwner;
}

- (NSString *)group {
    if (![self stat]) {
        return nil;
    }
    
    if (!cachedGroup) {
        const char *g = group_from_gid(cachedStatPtr->st_gid, 0);
        cachedGroup = @(g);
    }
    
    return cachedGroup;
}

- (NSString *)permissionsString {
    if (![self stat]) {
        return nil;
    }
    
    if (!cachedPermissionsString) {
        char buf[20];
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

- (NSString *)uti {
    if (cachedUTI) {
        return cachedUTI;
    }
    NSString *type = [[NSWorkspace sharedWorkspace] typeOfFile:_path error:nil];
    cachedUTI = (type == nil) ? @"" : type;
    return cachedUTI;
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
