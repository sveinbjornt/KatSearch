//
//  DateFormatterSingleton.h
//  KatSearch
//
//  Created by Sveinbjorn Thordarson on 21/05/2019.
//  Copyright © 2019 Sveinbjorn Thordarson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DateFormatter : NSObject

+(id)formatter;
- (NSString *)stringFromDate:(NSDate *)date;

@end
