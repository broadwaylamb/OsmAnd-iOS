//
//  OASimulationNavigationSettingViewController.h
//  OsmAnd
//
//  Created by nnngrach on 05.05.2022.
//  Copyright © 2022 OsmAnd. All rights reserved.
//

#import "OABaseNavbarViewController.h"
#import "OABaseSettingsViewController.h"

@interface OASimulationNavigationSettingViewController : OABaseNavbarViewController

@property (weak, nonatomic) id<OASettingsDataDelegate> delegate;

- (instancetype)initWithAppMode:(OAApplicationMode *)mode;

@end
