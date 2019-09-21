//
//  OARouteInfoView.m
//  OsmAnd
//
//  Created by Alexey Kulish on 10/08/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import "OARouteInfoView.h"
#import "OATargetPointsHelper.h"
#import "OARoutingHelper.h"
#import "OAAppModeCell.h"
#import "OARoutingTargetCell.h"
#import "OARoutingInfoCell.h"
#import "OARTargetPoint.h"
#import "OAPointDescription.h"
#import "Localization.h"
#import "OARootViewController.h"
#import "PXAlertView.h"
#import "OsmAndApp.h"
#import "OAApplicationMode.h"
#import "OADestinationsHelper.h"
#import "OADestination.h"
#import "OAFavoriteItem.h"
#import "OADestinationItem.h"
#import "OAMapActions.h"
#import "OAUtilities.h"
#import "OAWaypointUIHelper.h"
#import "OsmAnd_Maps-Swift.h"
#import "OAGPXDocument.h"
#import "OAGPXUIHelper.h"
#import "OAAppModeView.h"
#import "OAColors.h"

#include <OsmAndCore/Map/FavoriteLocationsPresenter.h>

#define kInfoViewLanscapeWidth 320.0

static int directionInfo = -1;
static BOOL visible = false;

typedef NS_ENUM(NSInteger, EOARouteInfoMenuState)
{
    EOARouteInfoMenuStateInitial = 0,
    EOARouteInfoMenuStateExpanded,
    EOARouteInfoMenuStateFullScreen
};

@interface OARouteInfoView ()<OARouteInformationListener, OAAppModeCellDelegate, OAWaypointSelectionDialogDelegate, UIGestureRecognizerDelegate>

@end

@implementation OARouteInfoView
{
    OATargetPointsHelper *_pointsHelper;
    OARoutingHelper *_routingHelper;
    OsmAndAppInstance _app;

    int _rowsCount;
    int _startPointRowIndex;
    int _intermediatePointsRowIndex;
    int _endPointRowIndex;
    int _routeInfoRowIndex;
    
    CALayer *_horizontalLine;
    CALayer *_verticalLine1;
    CALayer *_verticalLine2;
    
    BOOL _switched;
    
    OARouteStatisticsViewController *_routeStatsController;
    
    UIPanGestureRecognizer *_panGesture;
    EOARouteInfoMenuState _currentState;
    
    BOOL _isDragging;
}

- (instancetype) init
{
    NSArray *bundle = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:nil options:nil];
    
    for (UIView *v in bundle)
    {
        if ([v isKindOfClass:[OARouteInfoView class]])
            self = (OARouteInfoView *)v;
    }

    if (self)
    {
        [self commonInit];
    }
    
    return self;
}

- (instancetype) initWithFrame:(CGRect)frame
{
    NSArray *bundle = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:nil options:nil];
    for (UIView *v in bundle)
    {
        if ([v isKindOfClass:[OARouteInfoView class]])
            self = (OARouteInfoView *) v;
    }
    
    if (self)
    {
        [self commonInit];
        self.frame = frame;
    }
    
    return self;
}

- (void) awakeFromNib
{
    [super awakeFromNib];

    // drop shadow
    [self.layer setShadowColor:[UIColor blackColor].CGColor];
    [self.layer setShadowOpacity:0.3];
    [self.layer setShadowRadius:3.0];
    [self.layer setShadowOffset:CGSizeMake(0.0, 0.0)];
    
    _horizontalLine = [CALayer layer];
    _horizontalLine.backgroundColor = [[UIColor colorWithWhite:0.50 alpha:0.3] CGColor];
    _verticalLine1 = [CALayer layer];
    _verticalLine1.backgroundColor = [[UIColor colorWithWhite:0.50 alpha:0.3] CGColor];
    _verticalLine2 = [CALayer layer];
    _verticalLine2.backgroundColor = [[UIColor colorWithWhite:0.50 alpha:0.3] CGColor];
    
    [_buttonsView.layer addSublayer:_horizontalLine];
    [_buttonsView.layer addSublayer:_verticalLine1];
    [_buttonsView.layer addSublayer:_verticalLine2];

    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    _routeStatsController = [[OARouteStatisticsViewController alloc] init];
    [self addSubview:_routeStatsController.view];
    _routeStatsController.view.hidden = YES;
    
    self.layer.cornerRadius = 9.;
    self.sliderView.layer.cornerRadius = 3.;
    self.contentContainer.layer.cornerRadius = 9.;
    
    OAAppModeView *appModeView = [NSBundle.mainBundle loadNibNamed:@"OAAppModeView" owner:nil options:nil].firstObject;
    appModeView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [_appModeViewContainer addSubview:appModeView];
    appModeView.showDefault = NO;
    appModeView.delegate = self;
    appModeView.selectedMode = [_routingHelper getAppMode];
    
    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onDragged:)];
    _panGesture.maximumNumberOfTouches = 1;
    _panGesture.minimumNumberOfTouches = 1;
    [self addGestureRecognizer:_panGesture];
    _panGesture.delegate = self;
    _currentState = EOARouteInfoMenuStateInitial;
}

- (void) commonInit
{
    _app = [OsmAndApp instance];
    _pointsHelper = [OATargetPointsHelper sharedInstance];
    _routingHelper = [OARoutingHelper sharedInstance];

    [_routingHelper addListener:self];
}

+ (int) getDirectionInfo
{
    return directionInfo;
}

+ (BOOL) isVisible
{
    return visible;
}

- (void) updateData
{
    int index = 0;
    int count = 2;
    _startPointRowIndex = index++;
    _intermediatePointsRowIndex = -1;
    if ([self hasIntermediatePoints])
    {
        _intermediatePointsRowIndex = index++;
        count++;
    }
    _endPointRowIndex = index++;
    _routeInfoRowIndex = -1;
    if ([_routingHelper isRouteCalculated])
    {
        _routeInfoRowIndex = index++;
        count++;
        OAGPXDocument *gpx = [OAGPXUIHelper makeGpxFromRoute:_routingHelper.getRoute];
        OAGPXTrackAnalysis *analisys = [gpx getAnalysis:0];
        [_routeStatsController refreshLineChartWithAnalysis:analisys];
    }
    _rowsCount = count;
//    _routeStatsController.view.hidden = ![_routingHelper isRouteCalculated];
}

- (void) layoutSubviews
{
    if (_isDragging)
        return;
    [super layoutSubviews];
    
    [self adjustFrame];
    
    OAMapPanelViewController *mapPanel = [OARootViewController instance].mapPanel;
    if ([self isLandscape])
    {
        if (!self.tableView.tableHeaderView)
            self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, 20)];
        
        if (mapPanel.mapViewController.mapPositionX != 1)
        {
            mapPanel.mapViewController.mapPositionX = 1;
            [mapPanel refreshMap];
        }
    }
    else
    {
        if (self.tableView.tableHeaderView)
            self.tableView.tableHeaderView = nil;

        if (mapPanel.mapViewController.mapPositionX != 0)
        {
            mapPanel.mapViewController.mapPositionX = 0;
            [mapPanel refreshMap];
        }
    }
    
    double lineBorder = 12.0;
    
    _horizontalLine.frame = CGRectMake(0.0, 0.0, _buttonsView.frame.size.width, 0.5);
    _verticalLine1.frame = CGRectMake(_waypointsButton.frame.origin.x - 0.5, lineBorder, 0.5, _waypointsButton.frame.size.height - lineBorder * 2);
    _verticalLine2.frame = CGRectMake(_settingsButton.frame.origin.x - 0.5, lineBorder, 0.5, _waypointsButton.frame.size.height - lineBorder * 2);
    
    NSString *goTitle = OALocalizedString(@"shared_string_go");
    
    CGFloat border = 6.0;
    CGFloat imgWidth = 30.0;
    CGFloat minTextWidth = 100.0;
    CGFloat maxTextWidth = self.frame.size.width - _settingsButton.frame.origin.x - border * 2 - imgWidth - 16.0;
    
    UIFont *font = _goButton.titleLabel.font;
    CGFloat w = MAX(MIN([OAUtilities calculateTextBounds:goTitle width:1000.0 font:font].width + 16.0, maxTextWidth), minTextWidth) + imgWidth;
    
    [_goButton setTitle:goTitle forState:UIControlStateNormal];
    _goButton.frame = CGRectMake(_buttonsView.frame.size.width - w - border, border, w, _buttonsView.frame.size.height - [OAUtilities getBottomMargin] - border * 2);
    
    if (_intermediatePointsRowIndex == -1)
    {
        if ([self isLandscape])
        {
            CGRect sf = _swapButtonContainer.frame;
            sf.origin.y = 70;
            _swapButtonContainer.frame = sf;
        }
        else
        {
            CGRect sf = _swapButtonContainer.frame;
            sf.origin.y = 50;
            _swapButtonContainer.frame = sf;
        }
        _swapButtonContainer.hidden = NO;
    }
    else
    {
        _swapButtonContainer.hidden = YES;
    }
    
    CGRect sliderFrame = _sliderView.frame;
    sliderFrame.origin.x = self.bounds.size.width / 2 - sliderFrame.size.width / 2;
    _sliderView.frame = sliderFrame;
    
    CGRect buttonsFrame = _buttonsView.frame;
    buttonsFrame.size.width = self.bounds.size.width;
    _buttonsView.frame = buttonsFrame;
    
    CGRect contentFrame = _contentContainer.frame;
    contentFrame.size.width = self.bounds.size.width;
    _contentContainer.frame = contentFrame;
}

- (void) adjustFrame
{
    CGRect f = self.frame;
    CGFloat bottomMargin = [OAUtilities getBottomMargin];
    BOOL statsShown = !_routeStatsController.view.hidden;
    if ([self isLandscape])
    {
        f.origin = CGPointZero;
        f.size.height = DeviceScreenHeight;
        f.size.width = kInfoViewLanscapeWidth;
        if (bottomMargin > 0)
        {
            CGRect buttonsFrame = _buttonsView.frame;
            buttonsFrame.origin.y = f.size.height - 50 - bottomMargin;
            buttonsFrame.size.height = 50 + bottomMargin;
            _buttonsView.frame = buttonsFrame;
        }
        
        if (statsShown)
            _routeStatsController.view.frame = CGRectMake(0., CGRectGetMinY(_buttonsView.frame) - 150., f.size.width, 150.);
    }
    else
    {
        CGRect buttonsFrame = _buttonsView.frame;
        buttonsFrame.size.height = 50 + bottomMargin;
        f.size.height = [self getViewHeight];
        f.size.width = DeviceScreenWidth;
        f.origin = CGPointMake(0, DeviceScreenHeight - f.size.height);
        if (bottomMargin > 0)
        {
            buttonsFrame.origin.y = f.size.height - buttonsFrame.size.height;
            _buttonsView.frame = buttonsFrame;
        }
        CGRect contentFrame = _contentContainer.frame;
        contentFrame.size.height = f.size.height - buttonsFrame.size.height;
        contentFrame.origin = CGPointZero;
        _contentContainer.frame = contentFrame;
        
        _routeStatsController.view.frame = CGRectMake(0., CGRectGetMaxY(_tableView.frame) - 150., f.size.width, statsShown ? 150. : 0.);
    }
    self.frame = f;
}

- (CGFloat) getViewHeight
{
    switch (_currentState) {
        case EOARouteInfoMenuStateInitial:
            return _rowsCount * _tableView.rowHeight - 1.0 + _buttonsView.frame.size.height + _tableView.frame.origin.y;
        case EOARouteInfoMenuStateExpanded:
            return DeviceScreenHeight - DeviceScreenHeight / 4;
        case EOARouteInfoMenuStateFullScreen:
            return DeviceScreenHeight - OAUtilities.getStatusBarHeight;
        default:
            return 0.0;
    }
}

- (CGPoint) calculateInitialPoint
{
    return CGPointMake(0., DeviceScreenHeight - [self getViewHeight]);
}

- (IBAction) closePressed:(id)sender
{
    [[OARootViewController instance].mapPanel stopNavigation];
}

- (IBAction) waypointsPressed:(id)sender
{
    [[OARootViewController instance].mapPanel showWaypoints];
}

- (IBAction) settingsPressed:(id)sender
{
    [[OARootViewController instance].mapPanel showRoutePreferences];
}

- (IBAction) goPressed:(id)sender
{
    if ([_pointsHelper getPointToNavigate])
        [[OARootViewController instance].mapPanel closeRouteInfo];
    
    [[OARootViewController instance].mapPanel startNavigation];
}

- (IBAction) swapPressed:(id)sender
{
    [self switchStartAndFinish];
}

- (void) switchStartAndFinish
{
    OARTargetPoint *start = [_pointsHelper getPointToStart];
    OARTargetPoint *finish = [_pointsHelper getPointToNavigate];

    if (finish)
    {
        [_pointsHelper setStartPoint:[[CLLocation alloc] initWithLatitude:[finish getLatitude] longitude:[finish getLongitude]] updateRoute:NO name:[finish getPointDescription]];
        
        if (!start)
        {
            CLLocation *loc = _app.locationServices.lastKnownLocation;
            if (loc)
                [_pointsHelper navigateToPoint:loc updateRoute:YES intermediate:-1];
        }
        else
        {
            [_pointsHelper navigateToPoint:[[CLLocation alloc] initWithLatitude:[start getLatitude] longitude:[start getLongitude]] updateRoute:YES intermediate:-1 historyName:[start getPointDescription]];
        }

        [self show:NO onComplete:nil];
    }
}

- (BOOL) hasIntermediatePoints
{
    return [_pointsHelper getIntermediatePoints]  && [_pointsHelper getIntermediatePoints].count > 0;
}

- (NSString *) getRoutePointDescription:(double)lat lon:(double)lon
{
    return [NSString stringWithFormat:@"%@ %.3f %@ %.3f", OALocalizedString(@"Lat"), lat, OALocalizedString(@"Lon"), lon];
}

- (NSString *) getRoutePointDescription:(CLLocation *)l d:(NSString *)d
{
    if (d && d.length > 0)
        return [d stringByReplacingOccurrencesOfString:@":" withString:@" "];;

    if (l)
        return [NSString stringWithFormat:@"%@ %.3f %@ %.3f", OALocalizedString(@"Lat"), l.coordinate.latitude, OALocalizedString(@"Lon"), l.coordinate.longitude];
    
    return @"";
}

- (BOOL) isLandscape
{
    return DeviceScreenWidth > 470.0 && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone;
}

- (void) show:(BOOL)animated onComplete:(void (^)(void))onComplete
{
    visible = YES;
    
    [self updateData];
    [self setNeedsLayout];
    [self adjustFrame];
    [self.tableView reloadData];
    
    BOOL isNight = [OAAppSettings sharedManager].nightMode;
    OAMapPanelViewController *mapPanel = [OARootViewController instance].mapPanel;
    [mapPanel setTopControlsVisible:NO customStatusBarStyle:isNight ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault];
    [mapPanel setBottomControlsVisible:NO menuHeight:0 animated:YES];

    _switched = [mapPanel switchToRoutePlanningLayout];
    if (animated)
    {
        CGRect frame = self.frame;
        if ([self isLandscape])
        {
            frame.origin.x = -self.bounds.size.width;
            frame.origin.y = 0.0;
            frame.size.width = kInfoViewLanscapeWidth;
            self.frame = frame;
            
            frame.origin.x = 0.0;
        }
        else
        {
            frame.origin.x = 0.0;
            frame.origin.y = DeviceScreenHeight + 10.0;
            frame.size.width = DeviceScreenWidth;
            self.frame = frame;
            
            frame.origin.y = DeviceScreenHeight - self.bounds.size.height;
        }
        
        [UIView animateWithDuration:0.3 animations:^{
            
            self.frame = frame;
            
        } completion:^(BOOL finished) {
            if (onComplete)
                onComplete();
        }];
    }
    else
    {
        CGRect frame = self.frame;
        if ([self isLandscape])
            frame.origin.y = 0.0;
        else
            frame.origin.y = DeviceScreenHeight - self.bounds.size.height;
        
        self.frame = frame;
        
        if (onComplete)
            onComplete();
    }
}

- (void) hide:(BOOL)animated duration:(NSTimeInterval)duration onComplete:(void (^)(void))onComplete
{
    visible = NO;
    
    OAMapPanelViewController *mapPanel = [OARootViewController instance].mapPanel;
    [mapPanel setTopControlsVisible:YES];
    [mapPanel setBottomControlsVisible:YES menuHeight:0 animated:YES];

    if (self.superview)
    {
        CGRect frame = self.frame;
        if ([self isLandscape])
            frame.origin.x = -frame.size.width;
        else
            frame.origin.y = DeviceScreenHeight + 10.0;
        
        if (animated && duration > 0.0)
        {
            [UIView animateWithDuration:duration animations:^{
                
                self.frame = frame;
                
            } completion:^(BOOL finished) {
                
                [self removeFromSuperview];
                
                [self onDismiss];
                
                if (onComplete)
                    onComplete();
            }];
        }
        else
        {
            self.frame = frame;
            
            [self removeFromSuperview];
            
            [self onDismiss];

            if (onComplete)
                onComplete();
        }
    }
}

- (BOOL) isSelectingTargetOnMap
{
    OAMapPanelViewController *mapPanel = [OARootViewController instance].mapPanel;
    OATargetPointType activeTargetType = mapPanel.activeTargetType;
    return mapPanel.activeTargetActive && (activeTargetType == OATargetRouteStartSelection || activeTargetType == OATargetRouteFinishSelection || activeTargetType == OATargetRouteIntermediateSelection || activeTargetType == OATargetImpassableRoadSelection);
}

- (void) onDismiss
{
    OAMapPanelViewController *mapPanel = [OARootViewController instance].mapPanel;
    mapPanel.mapViewController.mapPositionX = 0;
    [mapPanel refreshMap];

    if (_switched)
        [mapPanel switchToRouteFollowingLayout];
    
    if (![_pointsHelper getPointToNavigate] && ![self isSelectingTargetOnMap])
        [mapPanel.mapActions stopNavigationWithoutConfirm];
}

- (void) addWaypoint
{
    // not implemented
}

- (void) update
{
    [self.tableView reloadData];
}

- (void) updateMenu
{
    if ([self superview])
        [self show:NO onComplete:nil];
}

#pragma mark - OAAppModeCellDelegate

- (void) appModeChanged:(OAApplicationMode *)next
{
    OAApplicationMode *am = [_routingHelper getAppMode];
    OAApplicationMode *appMode = [OAAppSettings sharedManager].applicationMode;
    if ([_routingHelper isFollowingMode] && appMode == am)
        [OAAppSettings sharedManager].applicationMode = next;

    [_routingHelper setAppMode:next];
    [_app initVoiceCommandPlayer:next warningNoneProvider:YES showDialog:NO force:NO];
    [_routingHelper recalculateRouteDueToSettingsChange];
}

#pragma mark - OARouteInformationListener

- (void) newRouteIsCalculated:(BOOL)newRoute
{
    dispatch_async(dispatch_get_main_queue(), ^{
        directionInfo = -1;
        [self updateMenu];
    });
}

- (void) routeWasUpdated
{
}

- (void) routeWasCancelled
{
    dispatch_async(dispatch_get_main_queue(), ^{
        directionInfo = -1;
        // do not hide fragment (needed for use case entering Planning mode without destination)
    });
}

- (void) routeWasFinished
{
}

#pragma mark - UITableViewDelegate

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == _startPointRowIndex)
    {
        static NSString* const reusableIdentifierPoint = @"OARoutingTargetCell";
        
        OARoutingTargetCell* cell;
        cell = (OARoutingTargetCell *)[self.tableView dequeueReusableCellWithIdentifier:reusableIdentifierPoint];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OARoutingTargetCell" owner:self options:nil];
            cell = (OARoutingTargetCell *)[nib objectAtIndex:0];
        }
        
        if (cell)
        {
            cell.finishPoint = NO;
            OARTargetPoint *point = [_pointsHelper getPointToStart];
            cell.titleLabel.text = OALocalizedString(@"route_from");
            if (point)
            {
                [cell.imgView setImage:[UIImage imageNamed:@"ic_list_startpoint"]];
                NSString *oname = [point getOnlyName].length > 0 ? [point getOnlyName] : [NSString stringWithFormat:@"%@: %@", OALocalizedString(@"map_settings_map"), [self getRoutePointDescription:[point getLatitude] lon:[point getLongitude]]];
                cell.addressLabel.text = oname;
            }
            else
            {
                [cell.imgView setImage:[UIImage imageNamed:@"ic_action_location_color"]];
                cell.addressLabel.text = OALocalizedString(@"shared_string_my_location");
            }
        }
        return cell;
    }
    else if (indexPath.row == _endPointRowIndex)
    {
        static NSString* const reusableIdentifierPoint = @"OARoutingTargetCell";
        
        OARoutingTargetCell* cell;
        cell = (OARoutingTargetCell *)[self.tableView dequeueReusableCellWithIdentifier:reusableIdentifierPoint];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OARoutingTargetCell" owner:self options:nil];
            cell = (OARoutingTargetCell *)[nib objectAtIndex:0];
        }
        
        if (cell)
        {
            cell.finishPoint = YES;
            OARTargetPoint *point = [_pointsHelper getPointToNavigate];
            [cell.imgView setImage:[UIImage imageNamed:@"ic_list_destination"]];
            cell.titleLabel.text = OALocalizedString(@"route_to");
            if (point)
            {
                NSString *oname = [self getRoutePointDescription:point.point d:[point getOnlyName]];
                cell.addressLabel.text = oname;
            }
            else
            {
                cell.addressLabel.text = OALocalizedString(@"route_descr_select_destination");
            }
        }
        return cell;
    }
    else if (indexPath.row == _intermediatePointsRowIndex)
    {
        static NSString* const reusableIdentifierPoint = @"OARoutingTargetCell";
        
        OARoutingTargetCell* cell;
        cell = (OARoutingTargetCell *)[self.tableView dequeueReusableCellWithIdentifier:reusableIdentifierPoint];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OARoutingTargetCell" owner:self options:nil];
            cell = (OARoutingTargetCell *)[nib objectAtIndex:0];
        }
        
        if (cell)
        {
            cell.finishPoint = NO;
            NSArray<OARTargetPoint *> *points = [_pointsHelper getIntermediatePoints];
            NSMutableString *via = [NSMutableString string];
            for (OARTargetPoint *point in points)
            {
                if (via.length > 0)
                    [via appendString:@" "];
                
                NSString *description = [point getOnlyName];
                [via appendString:[self getRoutePointDescription:point.point d:description]];
            }
            [cell.imgView setImage:[UIImage imageNamed:@"list_intermediate"]];
            cell.titleLabel.text = OALocalizedString(@"route_via");
            cell.addressLabel.text = via;
        }
        return cell;
    }
    else if (indexPath.row == _routeInfoRowIndex)
    {
        static NSString* const reusableIdentifierPoint = @"OARoutingInfoCell";
        
        OARoutingInfoCell* cell;
        cell = (OARoutingInfoCell *)[self.tableView dequeueReusableCellWithIdentifier:reusableIdentifierPoint];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OARoutingInfoCell" owner:self options:nil];
            cell = (OARoutingInfoCell *)[nib objectAtIndex:0];
        }
        
        if (cell)
        {
            cell.directionInfo = directionInfo;
            [cell updateControls];
            cell.distanceTitleLabel.text = OALocalizedString(@"shared_string_distance");
            cell.timeTitleLabel.text = OALocalizedString(@"shared_string_time");
        }
        return cell;
    }
    return nil;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == _startPointRowIndex)
    {
        OAWaypointSelectionDialog *dialog = [[OAWaypointSelectionDialog alloc] init];
        dialog.delegate = self;
        dialog.param = indexPath;
        [dialog selectWaypoint:OALocalizedString(@"route_from") target:NO intermediate:NO];
    }
    else if (indexPath.row == _endPointRowIndex)
    {
        OAWaypointSelectionDialog *dialog = [[OAWaypointSelectionDialog alloc] init];
        dialog.delegate = self;
        dialog.param = indexPath;
        [dialog selectWaypoint:OALocalizedString(@"route_to") target:YES intermediate:NO];
    }
    else if (indexPath.row == _intermediatePointsRowIndex)
    {
        [self waypointsPressed:nil];
    }
}

#pragma mark - OAWaypointSelectionDialogDelegate

- (void) waypointSelectionDialogComplete:(OAWaypointSelectionDialog *)dialog selectionDone:(BOOL)selectionDone showMap:(BOOL)showMap calculatingRoute:(BOOL)calculatingRoute
{
    if (selectionDone)
    {
        NSIndexPath *indexPath = dialog.param;
        if (!calculatingRoute && indexPath)
            [_tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        else
            [self.tableView reloadData];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _rowsCount;
}

#pragma mark - UIGestureRecognizerDelegate

- (void) onDragged:(UIPanGestureRecognizer *)recognizer
{
    CGPoint touchPoint = [recognizer locationInView:self.superview];
    CGPoint initialPoint = [self calculateInitialPoint];
    
    CGFloat expandedAnchor = DeviceScreenHeight / 4 + 40.;
    CGFloat fullScreenAnchor = OAUtilities.getStatusBarHeight + 40.;
    
    switch (recognizer.state)
    {
        case UIGestureRecognizerStateBegan:
            _isDragging = YES;
        case UIGestureRecognizerStateChanged:
        {
            CGRect frame = self.frame;
            frame.size.height = DeviceScreenHeight - touchPoint.y;
            frame.origin.y = frame.origin.y = touchPoint.y;
            self.frame = frame;
            
            CGRect buttonsFrame = _buttonsView.frame;
            buttonsFrame.origin.y = frame.size.height - buttonsFrame.size.height;
            _buttonsView.frame = buttonsFrame;
            
            CGRect contentFrame = _contentContainer.frame;
            contentFrame.size.height = frame.size.height - buttonsFrame.size.height;
            _contentContainer.frame = contentFrame;
            return;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _isDragging = NO;
            BOOL shouldRefresh = NO;
            if (touchPoint.y - initialPoint.y > 200 && _currentState == EOARouteInfoMenuStateInitial)
            {
                [self closePressed:nil];
                break;
            }
            else if (touchPoint.y < fullScreenAnchor)
            {
                _currentState = EOARouteInfoMenuStateFullScreen;
            }
            else if (touchPoint.y < expandedAnchor)
            {
                shouldRefresh = YES;
                _currentState = EOARouteInfoMenuStateExpanded;
            }
            else
            {
                shouldRefresh = YES;
                _currentState = EOARouteInfoMenuStateInitial;
            }
            if (shouldRefresh)
            {
                
            }
            
            
            [UIView animateWithDuration: 0.2 animations:^{
                [self layoutSubviews];
            }];
        }
        default:
        {
            break;
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return ![self isLandscape];
}

@end
