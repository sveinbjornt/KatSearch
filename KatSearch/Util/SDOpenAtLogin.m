/*
    Released under MIT license.

    Copyright (c) 2018 Steven Degutis

    Permission is hereby granted, free of charge, to any person obtaining a copy of
    this software and associated documentation files (the "Software"), to deal in
    the Software without restriction, including without limitation the rights to use,
    copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
    Software, and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
    PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
    OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import "SDOpenAtLogin.h"

@implementation SDOpenAtLogin

+ (LSSharedFileListRef)sharedFileList {
    static LSSharedFileListRef sharedFileList;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedFileList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    });
    return sharedFileList;
}

+ (void)setOpensAtLogin:(BOOL)opensAtLogin {
    NSURL *appURL = [[[NSBundle mainBundle] bundleURL] fileReferenceURL];
    
    if (opensAtLogin) {
        LSSharedFileListItemRef result = LSSharedFileListInsertItemURL([self sharedFileList],
                                                                       kLSSharedFileListItemLast,
                                                                       NULL,
                                                                       NULL,
                                                                       (__bridge CFURLRef)appURL,
                                                                       NULL,
                                                                       NULL);
        CFRelease(result);
    }
    else {
        UInt32 seed;
        NSArray *sharedFileListArray = (__bridge_transfer NSArray*)LSSharedFileListCopySnapshot([self sharedFileList], &seed);
        for (id item in sharedFileListArray) {
            LSSharedFileListItemRef sharedFileItem = (__bridge LSSharedFileListItemRef)item;
            CFURLRef url = NULL;
            
            OSStatus result = LSSharedFileListItemResolve(sharedFileItem, 0, &url, NULL);
            if (result == noErr && url != nil) {
                if ([appURL isEqual: [(__bridge NSURL*)url fileReferenceURL]])
                    LSSharedFileListItemRemove([self sharedFileList], sharedFileItem);
                
                CFRelease(url);
            }
        }
    }
}

+ (BOOL)opensAtLogin {
    NSURL *appURL = [[[NSBundle mainBundle] bundleURL] fileReferenceURL];
    
    UInt32 seed;
    NSArray *sharedFileListArray = (__bridge_transfer NSArray*)LSSharedFileListCopySnapshot([self sharedFileList], &seed);
    for (id item in sharedFileListArray) {
        LSSharedFileListItemRef sharedFileItem = (__bridge LSSharedFileListItemRef)item;
        CFURLRef url = NULL;
        
        OSStatus result = LSSharedFileListItemResolve(sharedFileItem, 0, &url, NULL);
        if (result == noErr && url != NULL) {
            BOOL foundIt = [appURL isEqual: [(__bridge NSURL*)url fileReferenceURL]];
            
            CFRelease(url);
            
            if (foundIt)
                return YES;
        }
    }
    
    return NO;
}

@end
