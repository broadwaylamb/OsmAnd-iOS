//
//  OABaseCollectionCell.m
//  OsmAnd Maps
//
//  Created by nnngrach on 06.05.2021.
//  Copyright © 2021 OsmAnd. All rights reserved.
//

#import "OABaseCollectionCell.h"

@implementation OABaseCollectionCell

+ (NSString *) getCellIdentifier
{
    return NSStringFromClass(self.class);
}

@end
