//
//  MenuImageAttachmentCell.m
//  KatSearch
//
//  Created by Sveinbjorn Thordarson on 01/06/2019.
//  Copyright © 2019 Sveinbjorn Thordarson. All rights reserved.
//

#import "MenuImageAttachmentCell.h"

@implementation MenuImageAttachmentCell

- (NSPoint)cellBaselineOffset {
    // Fix layout when image cell is attached to attributed
    // string for display in a menu item title.
    return NSMakePoint(0, -4);
}

@end
