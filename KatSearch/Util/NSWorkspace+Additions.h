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

#import <Cocoa/Cocoa.h>

@interface NSWorkspace (Additions)

- (NSArray *)applicationsForFile:(NSString *)filePath;
- (NSString *)defaultApplicationForFile:(NSString *)filePath;

- (NSDictionary *)labelDictionary;
- (BOOL)setLabelNamed:(NSString *)labelStr forFile:(NSString *)filePath;
- (BOOL)setLabelNumber:(NSUInteger)label forFile:(NSString *)filePath;
- (int)labelNumberForFile:(NSString *)path;
- (NSString *)labelNameForFile:(NSString *)path;
- (NSColor *)labelColorForFile:(NSString *)path;

- (unsigned long long)nrCalculateFolderSize:(NSString *)folderPath;
- (UInt64)fileOrFolderSize:(NSString *)path;
- (NSString *)fileSizeAsHumanReadableString:(UInt64)size;
- (NSString *)fileOrFolderSizeAsHumanReadable:(NSString *)path;
- (NSString *)createTempFileNamed:(NSString *)fileName withContents:(NSString *)str encoding:(NSStringEncoding)encoding;
- (NSString *)createTempFileNamed:(NSString *)fileName withContents:(NSString *)str;
- (NSString *)createTempFileWithContents:(NSString *)contentStr;
- (NSString *)createTempFileWithContents:(NSString *)contentStr encoding:(NSStringEncoding)textEncoding;

- (BOOL)showOriginal:(NSString *)path;
- (BOOL)moveFileToTrash:(NSString *)path;
- (BOOL)showFinderGetInfoForFile:(NSString *)path;
- (BOOL)quickLookFile:(NSString *)path;
- (BOOL)setFinderComment:(NSString *)comment forFile:(NSString *)filePath;
- (NSString *)finderCommentForFile:(NSString *)path;
- (void)notifyFinderFileChangedAtPath:(NSString *)path;
- (NSString *)kindStringForFile:(NSString *)path;

- (void)flushServices;
- (BOOL)openPathInDefaultBrowser:(NSString *)path;
- (BOOL)runCommandInTerminal:(NSString *)cmd;
- (BOOL)isFinderRunning;

@end
