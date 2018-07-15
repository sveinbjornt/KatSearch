/*
 Copyright (c) 2018, Sveinbjorn Thordarson <sveinbjorn@sveinbjorn.org>
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

#import "SearchTask.h"
#import "SearchItem.h"

@implementation SearchTask
{
    NSTask *task;
    NSFileHandle *readHandle;
    NSString *remnants;
    BOOL killed;
}

- (instancetype)initWithDelegate:(id<SearchTaskDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

#pragma mark -

- (void)start {
    
    task = [[NSTask alloc] init];
    task.launchPath = [[NSBundle mainBundle] pathForResource:@"searchfs" ofType:nil];
    if (!task.launchPath) {
        NSLog(@"searchfs binary not found in app bundle");
        NSBeep();
        [self stop];
    }
    task.currentDirectoryPath = [[NSBundle mainBundle] resourcePath];
    
    NSMutableArray *args = [@[@"-v", self.volume] mutableCopy];
    
    if (self.exactNameOnly) {
        [args addObject:@"-e"];
    }
    
    if (self.directoriesOnly) {
        [args addObject:@"-d"];
    }
    
    if (self.filesOnly) {
        [args addObject:@"-f"];
    }
    
    if (self.caseSensitive) {
        [args addObject:@"-s"];
    }

    if (self.skipPackages) {
        [args addObject:@"-p"];
    }
    
    if (self.skipInvisibles) {
        [args addObject:@"-i"];
    }
    
    if (self.skipInappropriate) {
        [args addObject:@"-x"];
    }
    
    if (self.negateSearchParams) {
        [args addObject:@"-n"];
    }
    
    [args addObject:self.searchString];
    task.arguments = args;
    
    NSPipe *outputPipe = [NSPipe pipe];
    [task setStandardOutput:outputPipe];
    [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    readHandle = [outputPipe fileHandleForReading];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gotOutputData:) name:NSFileHandleReadCompletionNotification object:readHandle];
    [readHandle readInBackgroundAndNotify];
    
    [task launch];
}

- (void)stop {
    if (!task) {
        return;
    }
    
    //    [task terminate];
    
    pid_t pid = [task processIdentifier];
    if (pid) {
        kill(pid, SIGKILL);
        // TODO: verify
        killed = YES;
    }
    
    task = nil;
    remnants = nil;
    readHandle = nil;
    
    if (self.delegate) {
        [self.delegate taskDidFinish:self];
    }
}

- (void)gotOutputData:(NSNotification *)aNotification {
    NSData *data = [aNotification userInfo][NSFileHandleNotificationDataItem];
    
    if ([data length] == 0) {
        if (self.delegate && !killed) {
            [self.delegate taskDidFinish:self];
        }
        return;
    }
        
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{ @autoreleasepool {
    
        NSMutableString *outputString = [[NSMutableString alloc] initWithData:data
                                                                     encoding:NSUTF8StringEncoding];
        if (remnants && [remnants length]) {
            [outputString insertString:remnants atIndex:0];
        }
        
        //NSLog(@"%@", outputString);
        NSMutableArray *paths = [[outputString componentsSeparatedByString:@"\n"] mutableCopy];
        remnants = [paths lastObject];
        [paths removeLastObject];
        
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *path in paths) {
            SearchItem *item = [[SearchItem alloc] initWithPath:path];
            if (item) {
                [items addObject:item];
            } else {
                NSLog(@"Error instantiating search item %@", path);
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate taskResultsFound:items];
        });
        
//    }});
    
    [[aNotification object] readInBackgroundAndNotify];
}

#pragma mark -

- (BOOL)isRunning {
    return [task isRunning];
}

@end
