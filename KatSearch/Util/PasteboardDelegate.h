//
//  PasteboardDelegate.h
//  KatSearch
//
//  Created by Sveinbjorn Thordarson on 17/04/2019.
//  Copyright © 2019 Sveinbjorn Thordarson. All rights reserved.
//

@protocol PasteboardDelegate <NSObject>
- (void)copySelectedFilesToPasteboard:(NSPasteboard *)pboard;
@end
