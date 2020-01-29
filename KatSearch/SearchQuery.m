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

#import <AppKit/AppKit.h>
#import "SearchQuery.h"
#import "MenuImageAttachmentCell.h"
#import "Common.h"

@implementation SearchQuery

+ (instancetype)defaultQuery {
    return [[self alloc] initWithDictionary:[[self class] defaultDict]];
}

+ (instancetype)searchQueryFromDictionary:(NSDictionary *)dict {
    return [[self alloc] initWithSearchQueryDictionary:dict];
}

- (instancetype)initWithSearchQueryDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        // First add entries from default. This makes us future-proof since
        // it allows us to safely read history items from a prior version.
        [self addEntriesFromDictionary:[[self class] defaultDict]];
        // Overwrite with the provided dict
        [self addEntriesFromDictionary:dict];
    }
    return self;
}

+ (NSDictionary *)defaultDict {
    // Default search settings
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
        // Clear
        [DEFAULTS setObject:@[] forKey:@"RecentSearches"];
    }
    
    // Insert as latest search
    NSMutableArray *recent = [[DEFAULTS objectForKey:@"RecentSearches"] mutableCopy];
    [recent insertObject:[NSDictionary dictionaryWithDictionary:self] atIndex:0];

    // Remove duplicate entries
    NSMutableSet *seenObjects = [NSMutableSet set];
    NSPredicate *dupPred = [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bind) {
        BOOL seen = [seenObjects containsObject:obj];
        if (!seen) {
            [seenObjects addObject:obj];
        }
        return !seen;
    }];
    [recent filterUsingPredicate:dupPred];
    
    // Remove older searches if we have exceeded maximum no. to store
    if ([recent count] >= NUM_RECENT_SEARCHES) {
        while ([recent count] >= NUM_RECENT_SEARCHES) {
            [recent removeLastObject];
        }
    }

    // Save
    [DEFAULTS setObject:[recent copy] forKey:@"RecentSearches"];
    [DEFAULTS synchronize];
}

#pragma mark -

//- (NSString *)matchTypeChar {
//    // Return a single character string describing the match type of the query
//    if ([self[@"matchtype"] isEqualToString:@"name is"]) {
//        return @"=";
//    }
//    if ([self[@"matchtype"] isEqualToString:@"name starts with"]) {
//        return @"^";
//    }
//    if ([self[@"matchtype"] isEqualToString:@"name ends with"]) {
//        return @"$";
//    }
//    return @"~";
//}

- (NSAttributedString *)menuItemString {
    // Generate an attributed string representation of the query,
    // suitable for display in an Open Recent menu
    
    // Create volume icon image cell
    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:self[@"volume"]];
    [icon setSize:NSMakeSize(16, 16)];
    id<NSTextAttachmentCell> cell = [[MenuImageAttachmentCell alloc] initImageCell:icon];
    NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
    [textAttachment setAttachmentCell:cell];
    
    // Create attributed string with image
    NSAttributedString *attrStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachment];
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithAttributedString:attrStringWithImage];
    
    // Prepend
    NSString *title = [NSString stringWithFormat:@"“%@” on ", self[@"searchstring"]];
    NSAttributedString *attrTitle = [[NSAttributedString alloc] initWithString:title];
    [str insertAttributedString:attrTitle atIndex:0];
    // Append
    NSString *volDisplayName = [[NSFileManager defaultManager] displayNameAtPath:self[@"volume"]];
    NSAttributedString *postStr = [[NSAttributedString alloc] initWithString:volDisplayName];
    [str appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
    [str appendAttributedString:postStr];
    
    return str;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Find %@ where %@ '%@' on '%@'",
            self[@"filetype"], self[@"matchtype"], self[@"searchstring"], self[@"volume"]];
}

@end
