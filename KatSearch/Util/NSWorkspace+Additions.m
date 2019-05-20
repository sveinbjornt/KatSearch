/*
    Copyright (c) 2003-2017, Sveinbjorn Thordarson <sveinbjorn@sveinbjorn.org>
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

#import "NSWorkspace+Additions.h"
#import <sys/stat.h>
#import <sys/types.h>
#import <dirent.h>

@implementation NSWorkspace (Additions)

#pragma mark - Application that handle files

- (NSArray *)applicationsForFile:(NSString *)filePath {
    NSURL *url = [NSURL fileURLWithPath:filePath];
    NSMutableArray *appPaths = [[NSMutableArray alloc] initWithCapacity:256];
    
    NSArray *applications = (NSArray *)CFBridgingRelease(LSCopyApplicationURLsForURL((__bridge CFURLRef)url, kLSRolesAll));
    if (applications == nil) {
        return @[];
    }
    
    for (int i = 0; i < [applications count]; i++) {
        [appPaths addObject:[applications[i] path]];
    }
    return appPaths;
}

- (NSString *)defaultApplicationForFile:(NSString *)filePath {
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    
    CFURLRef appURL = LSCopyDefaultApplicationURLForURL((__bridge CFURLRef)fileURL, kLSRolesAll, NULL);
    if (appURL) {
        NSString *appPath = [(__bridge NSURL *)appURL path];
        CFRelease(appURL);
        return appPath;
    }
    
    return nil;
}

#pragma mark - Labels

- (NSDictionary *)labelDictionary {
    NSString *fpath = @"~/Library/SyncedPreferences/com.apple.finder.plist";
    fpath = [fpath stringByExpandingTildeInPath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:fpath]) {
        return [self standardLabelDictionary];
    }
    
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:fpath];
    if (plist == nil) {
        return [self standardLabelDictionary];
    }
    
    NSArray *tags = [plist valueForKeyPath:@"values.FinderTagDict.value.FinderTags"];
    if (!tags) {
        return [self standardLabelDictionary];
    }
    
    
    return @{};
}

- (NSDictionary *)standardLabelDictionary {
    return @{};
}

- (BOOL)setLabelNamed:(NSString *)labelStr forFile:(NSString *)filePath {
    NSArray *fileLabels = [[[NSWorkspace sharedWorkspace] fileLabels] copy];
    NSUInteger labelNum;
    
    labelNum = [fileLabels indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return (BOOL)([obj caseInsensitiveCompare:labelStr] == NSOrderedSame);
    }];
    
    if (labelNum == NSNotFound) {
        // no str matches term case-insensitively
        
        // check if it's a number
        if ([labelStr length] != 1) {
            return NO;
        }
        NSNumber *num = [[NSNumberFormatter new] numberFromString:labelStr];
        if (num == nil) {
            return NO;
        }
        
        labelNum = [num unsignedIntegerValue];
    }
    
    return [self setLabelNumber:labelNum forFile:filePath];
}

- (BOOL)setLabelNumber:(NSUInteger)label forFile:(NSString *)filePath {
    if (label > 7) {
        NSLog(@"Error setting label %lu. Finder label must be in range 0-7", (unsigned long)label);
        return NO;
    }
    
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    NSError *error = nil;
    if (![fileURL setResourceValue:@(label) forKey:NSURLLabelNumberKey error:&error]) {
        NSLog(@"Error setting label: %@", [error localizedDescription]);
        return NO;
    }
    return YES;
}

- (int)labelNumberForFile:(NSString *)path {
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    id labelValue = nil;
    NSError *error;
    
    if (![fileURL getResourceValue:&labelValue forKey:NSURLLabelNumberKey error:&error]) {
        NSLog(@"An error occurred: %@", [error localizedDescription]);
        return -1;
    }
    
    return [labelValue intValue];
}

- (NSString *)labelNameForFile:(NSString *)path {
    int labelNum = [self labelNumberForFile:path];
    if (labelNum == 0) {
        return nil;
    }
    return [self fileLabels][labelNum];
}

- (NSColor *)labelColorForFile:(NSString *)path {
    int labelNum = [self labelNumberForFile:path];
    if (labelNum == -1) {
        return nil;
    }
    return [self fileLabelColors][labelNum];
}

#pragma mark - File/folder size

//  Copyright (c) 2015 Nikolai Ruhe. All rights reserved.
//
// This method calculates the accumulated size of a directory on the volume in bytes.
//
// As there's no simple way to get this information from the file system it has to crawl the entire hierarchy,
// accumulating the overall sum on the way. The resulting value is roughly equivalent with the amount of bytes
// that would become available on the volume if the directory would be deleted.
//
// Caveat: There are a couple of oddities that are not taken into account (like symbolic links, meta data of
// directories, hard links, ...).

- (BOOL)getAllocatedSize:(unsigned long long *)size ofDirectoryAtURL:(NSURL *)directoryURL error:(NSError * __autoreleasing *)error
{
    NSParameterAssert(size != NULL);
    NSParameterAssert(directoryURL != nil);
    
    // We'll sum up content size here:
    unsigned long long accumulatedSize = 0;
    
    // prefetching some properties during traversal will speed up things a bit.
    NSArray *prefetchedProperties = @[NSURLIsRegularFileKey,
                                      NSURLFileAllocatedSizeKey,
                                      NSURLTotalFileAllocatedSizeKey];
    
    // The error handler simply signals errors to outside code.
    __block BOOL errorDidOccur = NO;
    BOOL (^errorHandler)(NSURL *, NSError *) = ^(NSURL *url, NSError *localError) {
        if (error != NULL) {
            *error = localError;
        }
        errorDidOccur = YES;
        return NO;
    };
    
    // We have to enumerate all directory contents, including subdirectories.
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:directoryURL
                                                             includingPropertiesForKeys:prefetchedProperties
                                                                                options:(NSDirectoryEnumerationOptions)0
                                                                           errorHandler:errorHandler];
    
    // Start the traversal:
    for (NSURL *contentItemURL in enumerator) {
        
        // Bail out on errors from the errorHandler.
        if (errorDidOccur)
            return NO;
        
        // Get the type of this item, making sure we only sum up sizes of regular files.
        NSNumber *isRegularFile;
        if (! [contentItemURL getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:error])
            return NO;
        if (! [isRegularFile boolValue])
            continue; // Ignore anything except regular files.
        
        // To get the file's size we first try the most comprehensive value in terms of what the file may use on disk.
        // This includes metadata, compression (on file system level) and block size.
        NSNumber *fileSize;
        if (! [contentItemURL getResourceValue:&fileSize forKey:NSURLTotalFileAllocatedSizeKey error:error])
            return NO;
        
        // In case the value is unavailable we use the fallback value (excluding meta data and compression)
        // This value should always be available.
        if (fileSize == nil) {
            if (! [contentItemURL getResourceValue:&fileSize forKey:NSURLFileAllocatedSizeKey error:error])
                return NO;
            
            NSAssert(fileSize != nil, @"huh? NSURLFileAllocatedSizeKey should always return a value");
        }
        
        // We're good, add up the value.
        accumulatedSize += [fileSize unsignedLongLongValue];
    }
    
    // Bail out on errors from the errorHandler.
    if (errorDidOccur)
        return NO;
    
    // We finally got it.
    *size = accumulatedSize;
    return YES;
}

- (unsigned long long)nrCalculateFolderSize:(NSString *)folderPath {
    unsigned long long size = 0;
    NSURL *url = [NSURL fileURLWithPath:folderPath];
    [self getAllocatedSize:&size ofDirectoryAtURL:url error:nil];
    return size;
}

- (UInt64)fileOrFolderSize:(NSString *)path {
    NSString *fileOrFolderPath = [path copy];
    
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) {
        return 0;
    }
    
    // resolve if symlink
    NSDictionary *fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:fileOrFolderPath error:nil];
    if (fileAttrs) {
        NSString *fileType = [fileAttrs fileType];
        if ([fileType isEqualToString:NSFileTypeSymbolicLink]) {
            NSError *err;
            fileOrFolderPath = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:fileOrFolderPath error:&err];
            if (fileOrFolderPath == nil) {
                NSLog(@"Error resolving symlink %@: %@", path, [err localizedDescription]);
                fileOrFolderPath = path;
            }
        }
    }
    
    UInt64 size = 0;
    if (isDir) {
        NSDirectoryEnumerator *dirEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:fileOrFolderPath];
        while ([dirEnumerator nextObject]) {
            if ([NSFileTypeRegular isEqualToString:[[dirEnumerator fileAttributes] fileType]]) {
                size += [[dirEnumerator fileAttributes] fileSize];
            }
        }
        size = [[NSWorkspace sharedWorkspace] nrCalculateFolderSize:fileOrFolderPath];
    } else {
        size = [[[NSFileManager defaultManager] attributesOfItemAtPath:fileOrFolderPath error:nil] fileSize];
    }
    
    return size;
}

- (NSString *)fileOrFolderSizeAsHumanReadable:(NSString *)path {
    return [self fileSizeAsHumanReadableString:[self fileOrFolderSize:path]];
}

- (NSString *)fileSizeAsHumanReadableString:(UInt64)size {
    NSString *desc = nil;
    if (size < 1024ULL) {
        desc = [NSString stringWithFormat:@"%u bytes", (unsigned int)size];
    } else if (size < 1048576ULL) {
        desc = [NSString stringWithFormat:@"%llu KB", (UInt64)size / 1024];
    } else if (size < 1073741824ULL) {
        desc = [NSString stringWithFormat:@"%.1f MB", size / 1048576.0];
    } else {
        desc = [NSString stringWithFormat:@"%.1f GB", size / 1073741824.0];
    }
    if ([desc hasSuffix:@".0"]) {
        desc = [desc substringToIndex:[desc length] -2];
    }
    return desc;
}

#pragma mark - Temp file

- (NSString *)createTempFileNamed:(NSString *)fileName withContents:(NSString *)str encoding:(NSStringEncoding)textEncoding {
    // This could be done by just writing to /tmp, but this method is more secure
    // and will result in the script file being created at a path that looks something
    // like this:  /var/folders/yV/yV8nyB47G-WRvC76fZ3Be++++TI/-Tmp-/
    // Kind of ugly, but it's the Apple-sanctioned secure way of doing things with temp files
    // Thanks to Matt Gallagher for this technique:
    // http://cocoawithlove.com/2009/07/temporary-files-and-folders-in-cocoa.html
    
    NSString *tmpFileNameTemplate = fileName ? fileName : @"tmp_file_nsfilemgr_osx.XXXXXX";
    NSString *tmpDir = NSTemporaryDirectory();
    if (!tmpDir) {
        NSLog(@"NSTemporaryDirectory() returned nil");
        return nil;
    }
    
    NSString *tempFileTemplate = [tmpDir stringByAppendingPathComponent:tmpFileNameTemplate];
    const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
    char *tempFileNameCString = (char *)malloc(strlen(tempFileTemplateCString) + 1);
    strcpy(tempFileNameCString, tempFileTemplateCString);
    
    // use mkstemp to expand template
    int fileDescriptor = mkstemp(tempFileNameCString);
    if (fileDescriptor == -1) {
        free(tempFileNameCString);
        NSLog(@"Error %d in mkstemp()", errno);
        close(fileDescriptor);
        return nil;
    }
    close(fileDescriptor);
    
    // create nsstring from the c-string temp path
    NSString *tempScriptPath = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempFileNameCString length:strlen(tempFileNameCString)];
    free(tempFileNameCString);
    
    // write script to the temporary path
    NSError *err;
    BOOL success = [str writeToFile:tempScriptPath atomically:YES encoding:textEncoding error:&err];
    
    // make sure writing it was successful
    if (!success || [[NSFileManager defaultManager] fileExistsAtPath:tempScriptPath] == FALSE) {
        NSLog(@"Erroring creating temp file '%@': %@", tempScriptPath, [err localizedDescription]);
        return nil;
    }
    return tempScriptPath;
}

- (NSString *)createTempFileNamed:(NSString *)fileName withContents:(NSString *)contentStr {
    return [self createTempFileNamed:fileName withContents:contentStr encoding:NSUTF8StringEncoding];
}

- (NSString *)createTempFileWithContents:(NSString *)contentStr {
    return [self createTempFileNamed:nil withContents:contentStr encoding:NSUTF8StringEncoding];
}

- (NSString *)createTempFileWithContents:(NSString *)contentStr encoding:(NSStringEncoding)textEncoding {
    return [self createTempFileNamed:nil withContents:contentStr encoding:textEncoding];
}

#pragma mark - Finder

- (BOOL)showOriginal:(NSString *)path {
    NSData* bookmark = [NSURL bookmarkDataWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                      error:nil];
    NSError *error;
    NSURL *origURL = [NSURL URLByResolvingBookmarkData:bookmark
                                               options:NSURLBookmarkResolutionWithoutUI
                                         relativeToURL:nil
                                   bookmarkDataIsStale:nil
                                                 error:&error];
    if (origURL == nil) {
        NSLog(@"Unable to resolve bookmark %@", path);
        NSBeep();
        return NO;
    }
    
    BOOL succ = [[NSWorkspace sharedWorkspace] selectFile:path
                                 inFileViewerRootedAtPath:[path stringByDeletingLastPathComponent]];

    return succ;
}

- (BOOL)moveFileToTrash:(NSString *)path {
    
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    NSError *error;
    BOOL result = [[NSFileManager defaultManager] trashItemAtURL:fileURL
                                                resultingItemURL:nil
                                                           error:&error];
    if (!result) {
        NSLog(@"Error: %@", [error localizedDescription]);
    }

    return result;
    
//    NSString *script = @"\
//tell application \"Finder\"\n\
//    move POSIX file \"%@\" to trash\n\
//end tell";
//
//    NSString *src = [NSString stringWithFormat:script, path];
//    
//    // compile
//    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:src];
//    if (appleScript == nil) {
//        return NO;
//    }
//    
//    // execute
//    NSDictionary *errorInfo;
//    if ([appleScript executeAndReturnError:&errorInfo] == nil) {
//        NSLog(@"%@", [errorInfo description]);
//        return NO;
//    }
//    
//    return YES;
}

- (BOOL)showFinderGetInfoForFile:(NSString *)path {
    BOOL isDir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path
                                                       isDirectory:&isDir];
    if (!exists) {
        NSLog(@"Cannot show Get Info. File does not exist: %@", path);
        return NO;
    }
    
    NSString *type = isDir && ![self isFilePackageAtPath:path] ? @"folder" : @"file";
    
    NSString *source = [NSString stringWithFormat:
@"set aFile to (POSIX file \"%@\") as text\n\
tell application \"Finder\"\n\
\tactivate\n\
\topen information window of %@ aFile\n\
end tell", path, type];
    
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:source];
    if (appleScript != nil) {
        NSDictionary *errorInfo;
        if ([appleScript executeAndReturnError:&errorInfo] == nil) {
            NSLog(@"%@", [errorInfo description]);
            return NO;
        }
    }
    return YES;
}

- (BOOL)quickLookFile:(NSString *)path {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO) {
        NSBeep();
        return NO;
    }
    
    NSString *source = [NSString stringWithFormat:@"tell application \"Finder\"\n\
                        activate\n\
                        set imageFile to item (POSIX file \"%@\")\n\
                        select imageFile\n\
                        tell application \"System Events\" to keystroke \"y\" using command down\n\
                        end tell", path];
    
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:source];
    if (appleScript != nil) {
        NSDictionary *errorInfo;
        if ([appleScript executeAndReturnError:&errorInfo] == nil) {
            NSLog(@"%@", [errorInfo description]);
            return NO;
        }
    }
    return YES;
}


- (void)notifyFinderFileChangedAtPath:(NSString *)path {
    [[NSWorkspace sharedWorkspace] noteFileSystemChanged:path];
    NSString *source = [NSString stringWithFormat:@"tell application \"Finder\" to update item (POSIX file \"%@\")", path];
    
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:source];
    if (appleScript != nil) {
        NSDictionary *errorInfo;
        if ([appleScript executeAndReturnError:&errorInfo] == nil) {
            NSLog(@"%@", [errorInfo description]);
        }
    }
}

- (BOOL)setFinderComment:(NSString *)comment forFile:(NSString *)path {
    NSString *escapedComment = [comment stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSString *source = [NSString stringWithFormat:
@"set filePath to (POSIX file \"%@\") as text\n\
tell application \"Finder\"\n\
\tset comment of (filePath as alias) to \"%@\"\n\
end tell", path, escapedComment];
    
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:source];
    if (appleScript != nil) {
        NSDictionary *errorInfo;
        if ([appleScript executeAndReturnError:&errorInfo] == nil) {
            NSLog(@"%@", [errorInfo description]);
            return NO;
        }
    }

    return YES;
}

- (NSString *)finderCommentForFile:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    
    MDItemRef item = MDItemCreateWithURL(kCFAllocatorDefault, (CFURLRef)url);
    CFStringRef comment = MDItemCopyAttribute(item, kMDItemFinderComment);
    if (!comment) {
        CFRelease(item);
        return nil;
    }
    
    NSString *c = (__bridge NSString *)comment;
    CFRelease(item);
    CFRelease(comment);
    
    return c;
}

- (NSString *)kindStringForFile:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    NSString *kindStr;
    
    if (![url getResourceValue:&kindStr forKey:NSURLLocalizedTypeDescriptionKey error:nil]) {
        return @"Unknown";
    }
    
    return kindStr;
}

#pragma mark - Services

- (void)flushServices {
    // This call used to refresh Services without user having to log out/in
    // but may not do anything any more. Anyway, we'll keep invoking it for now
    NSUpdateDynamicServices();

    // This does the real deal
    [NSTask launchedTaskWithLaunchPath:@"/System/Library/CoreServices/pbs"
                             arguments:@[@"-flush"]];
}

#pragma mark - Misc

- (BOOL)openPathInDefaultBrowser:(NSString *)path {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO) {
        NSLog(@"File does not exist: %@", path);
        return NO;
    }
    
    NSURL *url = [NSURL URLWithString:@"http://"];
    NSString *appPath = nil;
    
    NSError *err = nil;
    CFErrorRef errRef = (__bridge CFErrorRef)err;
    CFURLRef browserPathURL = LSCopyDefaultApplicationURLForURL((__bridge CFURLRef)url, kLSRolesAll, &errRef);
    
    if (browserPathURL) {
        if (err == nil) {
            appPath = [(__bridge NSURL *)browserPathURL path];
        }
        CFRelease(browserPathURL);
    }
    
    if (!appPath) {
        NSLog(@"Unable to find default browser: %@", [err localizedDescription]);
        return NO;
    }
    
    [[NSWorkspace sharedWorkspace] openFile:path withApplication:appPath];
    return TRUE;
}

- (BOOL)runCommandInTerminal:(NSString *)cmd {
    NSString *osaCmd = [NSString stringWithFormat:@"tell application \"Terminal\"\n\tdo script \"%@\"\nactivate\nend tell", cmd];
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:osaCmd];
    id ret = [script executeAndReturnError:nil];
    return (ret != nil);
}

- (BOOL)isFinderRunning {
    NSArray *apps = [self runningApplications];
    for (NSRunningApplication *app in apps) {
        if ([[app bundleIdentifier] isEqualToString:@"com.apple.finder"]) {
            return YES;
        }
    }
    return NO;
}

@end
