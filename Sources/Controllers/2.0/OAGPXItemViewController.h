//
//  OAGPXItemViewController.h
//  OsmAnd
//
//  Created by Alexey Kulish on 16/02/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OATargetMenuViewController.h"

@class OAGPX;
@class OAGPXDocument;

@interface OAGPXItemViewController : OATargetMenuViewController<UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (nonatomic) OAGPX *gpx;

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentView;

@property (nonatomic, readonly) BOOL showCurrentTrack;

- (id)initWithGPXItem:(OAGPX *)gpxItem;
- (id)initWithCurrentGPXItem;
- (id)initWithCurrentGPXItemNoToolbar;

@end
