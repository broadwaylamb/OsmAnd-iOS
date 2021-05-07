//
//  OARadiusItemEx.h
//  OsmAnd
//
//  Created by Alexey Kulish on 19/03/2018.
//  Copyright © 2018 OsmAnd. All rights reserved.
//

#import "OABaseCell.h"

@interface OARadiusCellEx : OABaseCell

@property (weak, nonatomic) IBOutlet UIButton *buttonLeft;
@property (weak, nonatomic) IBOutlet UIButton *buttonRight;

- (void) setButtonLeftTitle:(NSString *)title description:(NSString *)description;
- (void) setButtonRightTitle:(NSString *)title description:(NSString *)description;

@end
