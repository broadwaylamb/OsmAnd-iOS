//
//  OAAltitudeWidget.h
//  OsmAnd
//
//  Created by Skalii on 19.04.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//
#import "OATextInfoWidget.h"

#define ALTITUDE_MAP_CENTER @"altitude_map_center"

typedef NS_ENUM(NSInteger, EOAAltitudeWidgetType) {
    EOAAltitudeWidgetTypeMyLocation = 0,
    EOAAltitudeWidgetTypeMapCenter
};

@interface OAAltitudeWidget : OATextInfoWidget

- (instancetype)initWithType:(EOAAltitudeWidgetType)widgetType;

@end
