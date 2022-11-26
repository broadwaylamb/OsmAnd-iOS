//
//  OATableDataModel.m
//  OsmAnd Maps
//
//  Created by Paul on 20.09.2022.
//  Copyright © 2022 OsmAnd. All rights reserved.
//

#import "OATableDataModel.h"
#import "OATableSectionData.h"
#import "OATableRowData.h"

@implementation OATableDataModel
{
    NSMutableArray<OATableSectionData *> *_sectionData;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _sectionData = [NSMutableArray array];
    }
    return self;
}

- (void)addSection:(OATableSectionData *)sectionData
{
    [_sectionData addObject:sectionData];
}

- (void)addSection:(OATableSectionData *)sectionData atIndex:(NSInteger)index
{
    if (index < _sectionData.count)
        [_sectionData insertObject:sectionData atIndex:index];
}


- (OATableSectionData *)sectionDataForIndex:(NSUInteger)index
{
    return _sectionData[index];
}

- (OATableRowData *)itemForIndexPath:(NSIndexPath *)indexPath
{
    OATableSectionData *section = _sectionData[indexPath.section];
    return [section getRow:indexPath.row];
}

- (NSUInteger)sectionCount
{
    return _sectionData.count;
}

- (NSUInteger)rowCount:(NSUInteger)section
{
    return _sectionData[section].rowCount;
}

@end