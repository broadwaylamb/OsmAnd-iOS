//
//  OATableViewCustomHeaderView.h
//  OsmAnd
//
//  Created by Paul on 7/3/19.
//  Copyright © 2019 OsmAnd. All rights reserved.
//

#import "OABaseHeaderFooterCell.h"

@interface OATableViewCustomHeaderView : OABaseHeaderFooterCell

@property (nonatomic, readonly) UITextView *label;

- (void) setYOffset:(CGFloat)yOffset;

+ (CGFloat) getHeight:(NSString *)text width:(CGFloat)width;
+ (CGFloat) getHeight:(NSString *)text width:(CGFloat)width yOffset:(CGFloat)yOffset font:(UIFont *)font;

@end

