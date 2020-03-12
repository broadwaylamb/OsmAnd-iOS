//
//  OAWaypointHeader.m
//  OsmAnd
//
//  Created by Alexey Kulish on 19/03/2018.
//  Copyright © 2018 OsmAnd. All rights reserved.
//

#import "OABottomSheetHeaderDescrButtonCell.h"
#import "OAUtilities.h"
#import "OAColors.h"

@implementation OABottomSheetHeaderDescrButtonCell

- (void) awakeFromNib
{
    self.sliderView.layer.cornerRadius = 3.;
    [super awakeFromNib];
}

- (void) setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
