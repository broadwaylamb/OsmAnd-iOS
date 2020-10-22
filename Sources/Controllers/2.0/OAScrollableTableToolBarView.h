//
//  OADraggableTableToolBarView.h
//  OsmAnd
//
//  Created by Paul on 16.10.2020.
//  Copyright © 2020 OsmAnd. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, EOADraggableMenuState)
{
    EOADraggableMenuStateInitial = 0,
    EOADraggableMenuStateExpanded,
    EOADraggableMenuStateFullScreen
};

@protocol OADraggableViewDelegate <NSObject>

- (void) onViewHeightChanged:(CGFloat)height;
- (void) onViewSwippedDown;

@end

@interface OAScrollableTableToolBarView : UIView

@property (nonatomic, readonly) CGFloat initialMenuHeight;
@property (nonatomic, readonly) CGFloat expandedMenuHeight;

@property (nonatomic, readonly) EOADraggableMenuState currentState;

@property (nonatomic, readonly) BOOL supportsFullScreen;

@property (strong, nonatomic) IBOutlet UIView *contentView;

@property (strong, nonatomic) IBOutlet UIView *sliderView;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) IBOutlet UIView *topHeaderContainerView;
@property (strong, nonatomic) IBOutlet UIView *toolBarView;
@property (strong, nonatomic) IBOutlet UIView *statusBarBackgroundView;
@property (strong, nonatomic) IBOutlet UIView *contentContainer;

@property (nonatomic, weak) id<OADraggableViewDelegate> delegate;

+ (BOOL) isVisible;

- (void) show:(BOOL)animated state:(EOADraggableMenuState)state onComplete:(void (^)(void))onComplete;
- (void) hide:(BOOL)animated duration:(NSTimeInterval)duration onComplete:(void (^)(void))onComplete;

- (void) goExpanded;
- (void) goMinimized;
- (void) goFullScreen;

- (CGFloat) getViewHeight:(EOADraggableMenuState)state;
- (CGFloat) getViewHeight;

@end
