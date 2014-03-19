//
//  OAOptionsPanelViewController.m
//  OsmAnd
//
//  Created by Alexey Pelykh on 8/20/13.
//  Copyright (c) 2013 OsmAnd. All rights reserved.
//

#import "OAOptionsPanelViewController.h"

#import "OsmAndApp.h"
#import "UIViewController+OARootVC.h"
#import "OAAutoObserverProxy.h"
#import "OAConfiguration.h"

#include "Localization.h"

@interface OAOptionsPanelViewController ()

@property (weak, nonatomic) IBOutlet UITableView *optionsTableview;

@end

@implementation OAOptionsPanelViewController
{
    OsmAndAppInstance _app;
    
    OAAutoObserverProxy* _configurationObserver;
}

#define kMapsSection 0
#define kMapsSection_Sources 0
#define kMapsSection_General 1
#define kMapsSection_Car 2
#define kMapsSection_Bicycle 3
#define kMapsSection_Pedestrian 4
#define kLayersSection 1
#define kSettingsSection 2

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self ctor];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self ctor];
    }
    return self;
}

- (void)ctor
{
    _app = [OsmAndApp instance];
    
    _configurationObserver = [[OAAutoObserverProxy alloc] initWith:self withHandler:@selector(onConfigurationChanged:withKey:andValue:)];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)onConfigurationChanged:(id)observable withKey:(id)key andValue:(id)value
{
    if([kMapSourceId isEqualToString:key])
    {
        // Force reload of list content
        dispatch_async(dispatch_get_main_queue(), ^{
            [_optionsTableview reloadData];
        });
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3 /* Maps section, Layers section, Settings section */;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section)
    {
        case kMapsSection:
        {
            NSInteger rowsCount = 1 /* 'Maps' */;
            if([_app.configuration.mapSourceId isEqualToString:kMapSourceId_OfflineMaps])
                rowsCount += 4 /* 'General', 'Car', 'Bicycle', 'Pedestrian' */;
                
            return rowsCount;
        } break;
        case kLayersSection:
            return 10;
        case kSettingsSection:
            return 1;
            
        default:
            return 0;
    }
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* const basicCellId = @"basicCell";
    static NSString* const onOffCellId = @"onOffCell";
    static NSString* const checkboxCellId = @"cellWithCheckbox";
    static NSString* const submenuCellId = @"cellWithSubmenu";
    
    // Get content for cell and it's type id
    NSString* cellTypeId = nil;
    UIImage* icon = nil;
    NSString* caption = nil;
    switch (indexPath.section)
    {
        case kMapsSection:
            if(indexPath.row == kMapsSection_Sources)
            {
                cellTypeId = submenuCellId;
                caption = OALocalizedString(@"Maps");
            }
            else
            {
                if([_app.configuration.mapSourceId isEqualToString:kMapSourceId_OfflineMaps])
                {
                    switch (indexPath.row)
                    {
                        case kMapsSection_General:
                            cellTypeId = checkboxCellId;
                            icon = [UIImage imageNamed:@"menu_general_map_icon.png"];
                            caption = OALocalizedString(@"General");
                            break;
                        case kMapsSection_Car:
                            cellTypeId = checkboxCellId;
                            icon = [UIImage imageNamed:@"menu_car_map_icon.png"];
                            caption = OALocalizedString(@"Car");
                            break;
                        case kMapsSection_Bicycle:
                            cellTypeId = checkboxCellId;
                            icon = [UIImage imageNamed:@"menu_bicycle_map_icon.png"];
                            caption = OALocalizedString(@"Bicycle");
                            break;
                        case kMapsSection_Pedestrian:
                            cellTypeId = checkboxCellId;
                            icon = [UIImage imageNamed:@"menu_pedestrian_map_icon.png"];
                            caption = OALocalizedString(@"Pedestrian");
                            break;
                    }
                }
            }
            break;
        case kLayersSection:
            break;
        case kSettingsSection:
            break;
    }
    if(cellTypeId == nil)
        cellTypeId = basicCellId;
    
    // Obtain reusable cell or create one
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellTypeId];
    if(cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellTypeId];
    
    // Fill cell content
    cell.imageView.image = icon;
    cell.textLabel.text = caption;
    
    return cell;
}

#pragma mark - UITableViewDelegate

#pragma mark -

/*
- (IBAction)activateMapnik:(id)sender {
    
    [self.rootViewController.mapPanel.rendererViewController activateMapnik];
    
}
- (IBAction)activateCyclemap:(id)sender {
    [self.rootViewController.mapPanel.rendererViewController activateCyclemap];
}
- (IBAction)activateOffline:(id)sender {
    [self.rootViewController.mapPanel.rendererViewController activateOffline];
}
*/
@end
