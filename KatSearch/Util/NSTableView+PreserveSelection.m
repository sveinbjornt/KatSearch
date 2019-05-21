/*
    Copyright (c) 2018-2019, Sveinbjorn Thordarson <sveinbjorn@sveinbjorn.org>
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

#import "NSTableView+PreserveSelection.h"

@implementation NSTableView (PreserveSelection)

- (void)reloadDataPreservingSelectionFromIndex:(NSInteger)idx1 toIndex:(NSInteger)idx2 {
//    NSIndexSet *selected = [self selectedRowIndexes];
//    NSLog(@"Reloading %d->%d", idx1, idx2);
//    [self reloadDataPreservingSelection];
//    return;
//    [self beginUpdates];
    [self beginUpdates];
    [self noteNumberOfRowsChanged];
//    [self reloadDataForRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.numberOfRows)]
//                    columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.numberOfColumns)]];
//    [self selectRowIndexes:selected byExtendingSelection:NO];
    [self endUpdates];
}

- (void)reloadDataPreservingSelection {
    NSIndexSet *selected = [self selectedRowIndexes];
    [self reloadData];
    [self selectRowIndexes:selected byExtendingSelection:NO];
}

@end
