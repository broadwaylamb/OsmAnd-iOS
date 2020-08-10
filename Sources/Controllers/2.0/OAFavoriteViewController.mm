//
//  OAFavoriteViewController.m
//  OsmAnd
//
//  Created by Alexey Kulish on 01/06/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAFavoriteViewController.h"
#import "OsmAndApp.h"
#import "OAAppData.h"
#import "OAAppSettings.h"
#import "OALog.h"
#import "OADefaultFavorite.h"
#import "OANativeUtilities.h"
#import "OAUtilities.h"
#import "OACollapsableView.h"
#import "OACollapsableWaypointsView.h"
#import <UIAlertView+Blocks.h>

#include <OsmAndCore.h>
#include <OsmAndCore/IFavoriteLocation.h>
#include "Localization.h"


@implementation OAFavoriteViewController
{
    OsmAndAppInstance _app;
}

- (BOOL) supportMapInteraction
{
    return YES;
}

- (BOOL) supportsForceClose
{
    return YES;
}

- (BOOL)shouldEnterContextModeManually
{
    return YES;
}

- (NSString *) getCommonTypeStr
{
    return OALocalizedString(@"favorite");
}

- (void) applyLocalization
{
    [super applyLocalization];
    
    self.titleView.text = OALocalizedString(@"favorite");
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    OAAppSettings* settings = [OAAppSettings sharedManager];
    [settings setShowFavorites:YES];
    self.titleGradient.frame = self.navBar.frame;
    
    [self.collapsableCoordinatesView setupWithLat:self.location.latitude lon:self.location.longitude];
}

-(void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self applySafeAreaMargins];
        self.titleGradient.frame = self.navBar.frame;
    } completion:nil];
}

- (BOOL) isItemExists:(NSString *)name
{
    for(const auto& localFavorite : [OsmAndApp instance].favoritesCollection->getFavoriteLocations())
        if ((localFavorite != self.favorite.favorite) &&
            [name isEqualToString:localFavorite->getTitle().toNSString()])
        {
            return YES;
        }
    
    return NO;
}

-(BOOL) preHide
{
    if (self.newItem && !self.actionButtonPressed)
    {
        [self removeNewItemFromCollection];
        return YES;
    }
    else
    {
        return [super preHide];
    }
}

- (void) okPressed
{
    if (self.savedColorIndex != -1)
        [[NSUserDefaults standardUserDefaults] setInteger:self.savedColorIndex forKey:kFavoriteDefaultColorKey];
    if (self.savedGroupName)
        [[NSUserDefaults standardUserDefaults] setObject:self.savedGroupName forKey:kFavoriteDefaultGroupKey];
    
    [super okPressed];
}

-(void) deleteItem
{
    [[[UIAlertView alloc] initWithTitle:@"" message:OALocalizedString(@"fav_remove_q") cancelButtonItem:[RIButtonItem itemWithLabel:OALocalizedString(@"shared_string_no")] otherButtonItems:
      [RIButtonItem itemWithLabel:OALocalizedString(@"shared_string_yes") action:^{
        
        OsmAndAppInstance app = [OsmAndApp instance];
        app.favoritesCollection->removeFavoriteLocation(self.favorite.favorite);
        [app saveFavoritesToPermamentStorage];
        
    }],
      nil] show];
}

- (void) saveItemToStorage
{
    [[OsmAndApp instance] saveFavoritesToPermamentStorage];
}

- (void) removeExistingItemFromCollection
{
    NSString *favoriteTitle = self.favorite.favorite->getTitle().toNSString();
    for(const auto& localFavorite : [OsmAndApp instance].favoritesCollection->getFavoriteLocations())
    {
        if ((localFavorite != self.favorite.favorite) &&
            [favoriteTitle isEqualToString:localFavorite->getTitle().toNSString()])
        {
            [OsmAndApp instance].favoritesCollection->removeFavoriteLocation(localFavorite);
            break;
        }
    }
}

- (void) removeNewItemFromCollection
{
    _app.favoritesCollection->removeFavoriteLocation(self.favorite.favorite);
    [_app saveFavoritesToPermamentStorage];
}

- (NSString *) getItemName
{
    if (!self.favorite.favorite->getTitle().isNull())
    {
        return self.favorite.favorite->getTitle().toNSString();
    }
    else
    {
        return @"";
    }
}

- (void) setItemName:(NSString *)name
{
    self.favorite.favorite->setTitle(QString::fromNSString(name));
}

- (UIColor *) getItemColor
{
    return [UIColor colorWithRed:self.favorite.favorite->getColor().r/255.0 green:self.favorite.favorite->getColor().g/255.0 blue:self.favorite.favorite->getColor().b/255.0 alpha:1.0];
}

- (void) setItemColor:(UIColor *)color
{
    CGFloat r,g,b,a;
    [color getRed:&r
            green:&g
             blue:&b
            alpha:&a];
    
    self.favorite.favorite->setColor(OsmAnd::FColorRGB(r,g,b));
}

- (NSString *) getItemGroup
{
    if (!self.favorite.favorite->getGroup().isNull())
    {
        return self.favorite.favorite->getGroup().toNSString();
    }
    else
    {
        return @"";
    }
}

- (void) setItemGroup:(NSString *)groupName
{
    self.favorite.favorite->setGroup(QString::fromNSString(groupName));
}

- (NSArray *) getItemGroups
{
    return [[OANativeUtilities QListOfStringsToNSMutableArray:_app.favoritesCollection->getGroups().toList()] copy];
}

- (NSString *) getItemDesc
{
    if (!self.favorite.favorite->getDescription().isNull())
    {
        return self.favorite.favorite->getDescription().toNSString();
    }
    else
    {
        return @"";
    }
}

- (void) setItemDesc:(NSString *)desc
{
    self.favorite.favorite->setDescription(QString::fromNSString(desc));
}

@end
