//
//  FileListTableView.m
//  KatSearch
//
//  Created by Sveinbjorn Thordarson on 13/07/2018.
//  Copyright © 2018 Sveinbjorn Thordarson. All rights reserved.
//

#import "FileListTableView.h"

@implementation FileListTableView

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
    
    [[self dataSource] performSelector:@selector(copySelectedFilesToPasteboard:) withObject:pboard];
    
    return YES;
}

@end
