//
//  KatPathControl.m
//  KatSearch
//
//  Created by Sveinbjorn Thordarson on 14/07/2018.
//  Copyright © 2018 Sveinbjorn Thordarson. All rights reserved.
//

#import "KatPathControl.h"

@implementation KatPathControl

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSApp registerServicesMenuSendTypes:@[NSFilenamesPboardType] returnTypes:@[]];
    });
}

- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType {
    if ([sendType isEqual:NSFilenamesPboardType]) {
        return self;
    }
    return [super validRequestorForSendType:sendType returnType:returnType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types {
    
    [[[self window] windowController] performSelector:@selector(copySelectedFilesToPasteboard:) withObject:pboard];
    
    return YES;
}


@end
