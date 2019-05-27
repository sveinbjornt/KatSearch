//
//  NSSharingServicePicker+ESSSharingServicePickerMenu.m
//
//  Created by Matthias Gansrigler on 22.11.12.
//  Copyright (c) 2012 Eternal Storms Software. All rights reserved.
//

#import "NSSharingServicePicker+ESSSharingServicePickerMenu.h"

@implementation NSSharingServicePicker (ESSSharingServicePickerMenu)

+ (NSMenu *)menuForSharingItems:(NSArray *)items
                     withTarget:(id)target //the target to which aSel will be sent to
                       selector:(SEL)aSel  //aSel like: mySelector:(NSMenuItem *)it -> it.representedObject = service according to menu item title.
                serviceDelegate:(id <NSSharingServiceDelegate>)del
{
    NSArray *sharingServices = [NSSharingService sharingServicesForItems:items];
    if (sharingServices.count == 0)
        return nil;
    
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"ShareMenu"];
    
    // Rebuild the menu
    for (NSSharingService *currentService in sharingServices)
    {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:currentService.title action:aSel keyEquivalent:@""];
        item.image = currentService.image;
        item.representedObject = currentService;
        currentService.delegate = del;
        item.target = target;
        [menu addItem:item];
    }
    
    return menu;
}

@end
