//
//  OAMapSettingsMapTypeScreen.h
//  OsmAnd
//
//  Created by Alexey Kulish on 21/02/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAMapSettingsScreen.h"

@protocol OAMapTypeDelegate <NSObject>

@required

- (void)refreshMenuRoutesParameters:(OAMapSource *)source;

@end

@interface OAMapSettingsMapTypeScreen : NSObject<OAMapSettingsScreen>

@property (weak, nonatomic) id<OAMapTypeDelegate> delegate;

@end
