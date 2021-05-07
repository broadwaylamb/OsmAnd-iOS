//
//  OAHomeWorkCell.h
//  OsmAnd
//
//  Created by Paul on 26/12/2018.
//  Copyright © 2018 OsmAnd. All rights reserved.
//

#import "OABaseCell.h"
#import "MaterialTextFields.h"

@protocol OAHomeWorkCellDelegate <NSObject>

@required

- (void) onItemSelected:(NSString *) key;
- (void) onItemSelected:(NSString *) key overrideExisting:(BOOL)overrideExisting;

@end

@interface OAHomeWorkCell : OABaseCell

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@property (nonatomic) id<OAHomeWorkCellDelegate> delegate;

- (void) generateData;

@end
