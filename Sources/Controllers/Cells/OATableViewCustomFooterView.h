//
//  OATableViewCustomFooterView.h
//  OsmAnd
//
//  Created by Paul on 7/3/19.
//  Copyright © 2019 OsmAnd. All rights reserved.
//

#import "OABaseHeaderFooterCell.h"

@interface OATableViewCustomFooterView : OABaseHeaderFooterCell

@property (nonatomic, readonly) UITextView *label;

- (void) setIcon:(NSString *)imageName;

+ (CGFloat) getHeight:(NSString *)text width:(CGFloat)width;

@end

