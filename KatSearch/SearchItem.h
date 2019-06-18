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

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#define SI_UNKNOWN @"?"

@interface SearchItem : NSObject

@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSString *lowercaseName;
@property (readonly, nonatomic) NSString *path;
@property (readonly, nonatomic) NSURL *url;
@property (readonly, nonatomic) NSImage *icon;

@property (readonly, nonatomic) UInt64 size;
@property (readonly, nonatomic) NSString *rawSizeString;
@property (readonly, nonatomic) NSString *sizeString;

@property (readonly, nonatomic) NSDate *dateAccessed;
@property (readonly, nonatomic) NSString *dateAccessedString;
@property (readonly, nonatomic) NSString *dateAccessedISOString;

@property (readonly, nonatomic) NSDate *dateCreated;
@property (readonly, nonatomic) NSString *dateCreatedString;
@property (readonly, nonatomic) NSString *dateCreatedISOString;

@property (readonly, nonatomic) NSDate *dateModified;
@property (readonly, nonatomic) NSString *dateModifiedString;
@property (readonly, nonatomic) NSString *dateModifiedISOString;

@property (readonly, nonatomic) NSString *kind;
@property (readonly, nonatomic) NSString *HFSType;
@property (readonly, nonatomic) NSString *creatorType;
@property (readonly, nonatomic) NSString *MIMEType;
@property (readonly, nonatomic) NSString *UTI;

@property (readonly, nonatomic) NSString *user;
@property (readonly, nonatomic) NSString *group;
@property (readonly, nonatomic) NSString *userGroupString;

@property (readonly, nonatomic) NSUInteger permissionsNumber;
@property (readonly, nonatomic) NSString *permissionsString;
@property (readonly, nonatomic) NSString *permissionsNumberString;

@property (readonly, nonatomic) BOOL isBookmark;
@property (readonly, nonatomic) BOOL isSymlink;
@property (readonly, nonatomic) BOOL isDirectory;
@property (readonly, nonatomic) BOOL isHidden;
@property (readonly, nonatomic) BOOL isPackage;
@property (readonly, nonatomic) BOOL isApp;
@property (readonly, nonatomic) BOOL exists;

@property (readonly, nonatomic) NSString *defaultHandlerApplication;
@property (readonly, nonatomic) NSArray<NSString *> *handlerApplications;

- (instancetype)initWithPath:(NSString *)path;

- (NSString *)truncatedName:(NSUInteger)maxChars;

- (void)prime;
- (void)open;
- (void)showInFinder;
- (void)showPackageContents;
- (void)openWith:(NSString *)appIdentifier;
- (void)getInfo;
- (void)showOriginal;
- (void)quickLook;

@end
