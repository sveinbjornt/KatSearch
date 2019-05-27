//
//  NSSharingServicePicker+ESSSharingServicePickerMenu.h
//
//  Created by Matthias Gansrigler on 22.11.12.
//  Copyright (c) 2012 Eternal Storms Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSSharingServicePicker (ESSSharingServicePickerMenu)

+ (NSMenu *)menuForSharingItems:(NSArray *)items
                     withTarget:(id)target //the target to which aSel will be sent to
                       selector:(SEL)aSel //aSel like: mySelector:(NSMenuItem *)it -> it.representedObject = service according to menu item title.
                serviceDelegate:(id <NSSharingServiceDelegate>)del;

@end
