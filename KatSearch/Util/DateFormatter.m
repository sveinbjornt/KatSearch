//
//  DateFormatterSingleton.m
//  KatSearch
//
//  Created by Sveinbjorn Thordarson on 21/05/2019.
//  Copyright © 2019 Sveinbjorn Thordarson. All rights reserved.
//

#import "DateFormatter.h"
#import <Cocoa/Cocoa.h>

@interface DateFormatter()
{
    NSDateFormatter *formatter;
}
@end

@implementation DateFormatter

+(id)formatter {
    
    static DateFormatter *instance = nil; //Local static variable
    //All access to this local static variable must go through +sharedInstance
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
    });
    
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSLog(@"Creating date formatter");
        formatter = [NSDateFormatter new];
        formatter.doesRelativeDateFormatting = YES;
        formatter.locale = [NSLocale currentLocale];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
    }
    return self;
}

- (NSString *)stringFromDate:(NSDate *)date {
    return [formatter stringFromDate:date];
}

@end
