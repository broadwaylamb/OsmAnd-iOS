//
//  OAMenuSimpleCell.h
//  OsmAnd
//
//  Created by Alexey Kulish on 04/04/2018.
//  Copyright © 2018 OsmAnd. All rights reserved.
//

#import "OABaseCell.h"

@interface OAMenuSimpleCell : OABaseCell

@property (weak, nonatomic) IBOutlet UIImageView *imgView;
@property (weak, nonatomic) IBOutlet UILabel *textView;
@property (weak, nonatomic) IBOutlet UILabel *descriptionView;

@property (nonatomic) IBOutlet NSLayoutConstraint *textBottomMargin;
@property (nonatomic) IBOutlet NSLayoutConstraint *descrTopMargin;
@property (nonatomic) IBOutlet NSLayoutConstraint *textHeightPrimary;
@property (nonatomic) IBOutlet NSLayoutConstraint *textHeightSecondary;

@end
