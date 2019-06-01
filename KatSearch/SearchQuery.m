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

#import <AppKit/AppKit.h>
#import "SearchQuery.h"
#import "MenuImageAttachmentCell.h"
#import "Common.h"

@implementation SearchQuery

+ (instancetype)defaultQuery {
    return [[[self class] alloc] initWithDictionary:[[self class] defaultDict]];
}

+ (instancetype)searchQueryFromDictionary:(NSDictionary *)dict {
    return [[[self class] alloc] initWithSearchQueryDictionary:dict];
}

- (instancetype)initWithSearchQueryDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        [self addEntriesFromDictionary:[[self class] defaultDict]];
        [self addEntriesFromDictionary:dict];
    }
    return self;
}

+ (NSDictionary *)defaultDict {
    return @{
        @"filetype": [DEFAULTS stringForKey:@"FindItemTypes"],
        @"matchtype": [DEFAULTS stringForKey:@"FindNameMatch"],
        @"searchstring": @"",
        @"volume": [DEFAULTS stringForKey:@"FindOnVolume"],
        @"casesensitive": [DEFAULTS objectForKey:@"CaseSensitive"],
        @"skippackages": [DEFAULTS objectForKey:@"SkipPackageContents"],
        @"skipinvisibles": [DEFAULTS objectForKey:@"SkipInvisibleFiles"],
        @"skipsystemfolder": [DEFAULTS objectForKey:@"SkipSystemFolder"]
    };
}

#pragma mark -

- (void)saveAsRecentSearch {
    if (![DEFAULTS objectForKey:@"RecentSearches"]) {
        [DEFAULTS setObject:@[] forKey:@"RecentSearches"];
    }
    NSMutableArray *recent = [[DEFAULTS objectForKey:@"RecentSearches"] mutableCopy];
    if ([recent count] >= NUM_RECENT_SEARCHES) {
        while ([recent count] >= NUM_RECENT_SEARCHES) {
            [recent removeLastObject];
        }
    }
    [recent insertObject:[NSDictionary dictionaryWithDictionary:self] atIndex:0];
    [DEFAULTS setObject:[recent copy] forKey:@"RecentSearches"];
    [DEFAULTS synchronize];
}

#pragma mark -

- (id)menuDescription {
    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:@"/"];
    [icon setSize:NSMakeSize(16, 16)];
    id<NSTextAttachmentCell> cell = [[MenuImageAttachmentCell alloc] initImageCell:icon];
//    [(NSTextAttachmentCell *)cell setCellBaselineOffset:-10];
    
    NSTextAttachment *textAttachment = [[NSTextAttachment alloc] initWithData:nil ofType:nil];
    [textAttachment setAttachmentCell:cell];

    // Create text attachment
//    NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
//    textAttachment.image = icon;//[NSImage imageNamed:@"NSApplicationIcon"];
//    textAttachment.bounds = CGRectMake(0, 0, 16, 16);
    
    // Attribute
    NSAttributedString *attrStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachment];
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithAttributedString:attrStringWithImage];

    NSString *title = [NSString stringWithFormat:@"“%@” on ", self[@"searchstring"]];
    NSAttributedString *attrTitle = [[NSAttributedString alloc] initWithString:title];
    [str insertAttributedString:attrTitle atIndex:0];
    NSAttributedString *postStr = [[NSAttributedString alloc] initWithString:self[@"volume"]];
    [str appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
    [str appendAttributedString:postStr];
    return [str copy];
//    return [self description];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ where %@ '%@' on '%@'",
            self[@"filetype"], self[@"matchtype"], self[@"searchstring"], self[@"volume"]];
}

@end