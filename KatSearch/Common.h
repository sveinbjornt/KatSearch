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

#define PROGRAM_NAME                @"KatSearch"

#define PROGRAM_VERSION_MAJ         1
#define PROGRAM_VERSION_MIN         0
#define PROGRAM_VERSION_STRING      @[NSString stringWithFormat:@"%d.%d",\
                                    PROGRAM_VERSION_MAJ, PROGRAM_VERSION_MIN]

#define PROGRAM_WEBSITE_URL         @"https://sveinbjorn.org/katsearch"
#define PROGRAM_DONATIONS_URL       @"https://sveinbjorn.org/donations"
#define PROGRAM_GITHUB_URL          @"https://github.com/sveinbjornt/KatSearch"
#define PROGRAM_LICENSE_FILE        @"License.html"
#define PROGRAM_MAN_PAGE_FILE       @"searchfs.1.html"
#define PROGRAM_DOCUMENTATION_FILE  @"Documentation.html"

#define SHORTCUT_DEFAULT_NAME       @"GlobalShortcut"
#define SHORTCUT_DEFAULT_KEYCODE    0

#define CLT_BIN_NAME                @"searchfs"
#define CLT_MAN_NAME                @"searchfs.1.gz"
#define CLT_INSTALL_PATH            @"/usr/local/bin/searchfs"
#define CLT_MAN_INSTALL_PATH        @"/usr/local/share/man/man1/searchfs.1.gz"

#define NUM_RECENT_SEARCHES         15

#define VALUES_KEYPATH(X)           [NSString stringWithFormat:@"values.%@", (X)]

#define DEFAULTS                    [NSUserDefaults standardUserDefaults]

#define COL_DEFAULT_PREFIX          @"ShowColumn"

#define COLUMNS                     @[@"Kind", @"Size", @"DateCreated", @"DateModified", \
                                      @"DateAccessed", @"UserGroup", @"Permissions", @"UTI", \
                                      @"MIMEType", @"FileType", @"CreatorType"]

// Logging
#ifdef DEBUG
    #define DLog(...) NSLog(__VA_ARGS__)
#else
    #define DLog(...)
#endif
