//
//  OALocalResourceInformationViewController.mm
//  OsmAnd
//
//  Created by Alexey Pelykh on 5/17/14.
//  Copyright (c) 2014 OsmAnd. All rights reserved.
//

#import "OALocalResourceInformationViewController.h"

#import "OsmAndApp.h"
#include "Localization.h"
#import "OALocalResourceInfoCell.h"
#import "OAButtonCell.h"
#import "OAPurchasesViewController.h"
#import "OAPluginsViewController.h"
#import "OAUtilities.h"
#import "OAMapCreatorHelper.h"
#import "OASizes.h"

typedef OsmAnd::ResourcesManager::LocalResource OsmAndLocalResource;

@interface OALocalResourceInformationViewController ()<UITableViewDelegate, UITableViewDataSource> {
    
    NSArray *tableKeys;
    NSArray *tableValues;
    NSArray *tableButtons;
    
    NSDateFormatter *formatter;
    
    NSString *_resourceId;
}

@end

@implementation OALocalResourceInformationViewController
{
    CALayer *_horizontalLine;
}

-(void)applyLocalization
{
    _titleView.text = OALocalizedString(@"res_details");
    
    [_btnToolbarMaps setTitle:OALocalizedString(@"maps") forState:UIControlStateNormal];
    [_btnToolbarPlugins setTitle:OALocalizedString(@"plugins") forState:UIControlStateNormal];
    [_btnToolbarPurchases setTitle:OALocalizedString(@"purchases") forState:UIControlStateNormal];
    [OAUtilities layoutComplexButton:self.btnToolbarMaps];
    [OAUtilities layoutComplexButton:self.btnToolbarPlugins];
    [OAUtilities layoutComplexButton:self.btnToolbarPurchases];
}

-(void)viewDidLoad
{
    [super viewDidLoad];

    _horizontalLine = [CALayer layer];
    _horizontalLine.backgroundColor = [UIColorFromRGB(kBottomToolbarTopLineColor) CGColor];
    self.toolbarView.backgroundColor = UIColorFromRGB(kBottomToolbarBackgroundColor);
    [self.toolbarView.layer addSublayer:_horizontalLine];
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    _horizontalLine.frame = CGRectMake(0.0, 0.0, DeviceScreenWidth, 0.5);
    self.tableView.separatorInset = UIEdgeInsetsMake(0., [OAUtilities getLeftMargin] + 16.0, 0., 0.);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.backButton setImage:self.backButton.imageView.image.imageFlippedForRightToLeftLayoutDirection forState:UIControlStateNormal];
    if (self.regionTitle)
        self.titleView.text = self.regionTitle;

    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    [self applySafeAreaMargins];
}

-(UIView *) getTopView
{
    return _navBarView;
}

-(UIView *) getMiddleView
{
    return _tableView;
}

-(UIView *) getBottomView
{
    return _toolbarView;
}

-(CGFloat) getToolBarHeight
{
    return defaultToolBarHeight;
}

-(IBAction)backButtonClicked:(id)sender;
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) deleteClicked
{
    if (!_localItem)
        return;
    
    [self.baseController offerDeleteResourceOf:self.localItem executeAfterSuccess:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController popViewControllerAnimated:YES];
        });
    }];
}

- (void) clearCacheClicked
{
    
}

- (void)initWithLocalSqliteDbItem:(SqliteDbResourceItem *)item;
{
    self.localItem = item;
    
    NSMutableArray *tKeys = [NSMutableArray array];
    NSMutableArray *tValues = [NSMutableArray array];
    NSMutableArray *tButtons = [NSMutableArray array];
    
    // Type
    [tKeys addObject:OALocalizedString(@"res_type")];
    [tValues addObject:OALocalizedString(@"map_creator")];
    
    // Size
    [tKeys addObject:OALocalizedString(@"res_size")];
    [tValues addObject:[NSByteCountFormatter stringFromByteCount:item.size countStyle:NSByteCountFormatterCountStyleFile]];
    
    // Timestamp
    NSError *error;
    NSURL *fileUrl = [NSURL fileURLWithPath:item.path];
    NSDate *d;
    [fileUrl getResourceValue:&d forKey:NSURLCreationDateKey error:&error];
    if (!error)
    {
        [tKeys addObject:OALocalizedString(@"res_created_on")];
        
        if (!formatter) {
            formatter = [[NSDateFormatter alloc] init];
            [formatter setDateStyle:NSDateFormatterShortStyle];
            [formatter setTimeStyle:NSDateFormatterShortStyle];
        }
        
        [tValues addObject:[NSString stringWithFormat:@"%@", [formatter stringFromDate:d]]];
        [tButtons addObject:[self getButtonCell:(NSString *)@"clear_cache"]];
        [tButtons addObject:[self getButtonCell:(NSString *)@"delete"]];
    }
    
    tableKeys = tKeys;
    tableValues = tValues;
    tableButtons = tButtons;
}

- (void)initWithLocalOnlineSourceItem:(OnlineTilesResourceItem *)item
{
    self.localItem = item;
    
    NSMutableArray *tKeys = [NSMutableArray array];
    NSMutableArray *tValues = [NSMutableArray array];
    NSMutableArray *tButtons = [NSMutableArray array];
    
    // Type
    [tKeys addObject:OALocalizedString(@"res_type")];
    [tValues addObject:OALocalizedString(@"online_map")];
    
    // Size
    [tKeys addObject:OALocalizedString(@"res_size")];
    [tValues addObject:@"calculating_progress"];
    
    [tButtons addObject:[self getButtonCell:(NSString *)@"clear_cache"]];
    [tButtons addObject:[self getButtonCell:(NSString *)@"delete"]];
    
    tableKeys = tKeys;
    tableValues = tValues;
    tableButtons = tButtons;
    
    [self calculateSizeAndUpdate:item];
}

- (void) calculateSizeAndUpdate:(OnlineTilesResourceItem *)item
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSString *size = [NSByteCountFormatter stringFromByteCount:[OAUtilities folderSize:item.path] countStyle:NSByteCountFormatterCountStyleFile];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            NSMutableArray *tKeys = [NSMutableArray array];
            NSMutableArray *tValues = [NSMutableArray array];
            
            // Type
            [tKeys addObject:OALocalizedString(@"res_type")];
            [tValues addObject:OALocalizedString(@"online_map")];
            
            // Size
            [tKeys addObject:OALocalizedString(@"res_size")];
            [tValues addObject:size];
            
            tableKeys = tKeys;
            tableValues = tValues;
            
            [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
        });
    });
}

- (void)initWithLocalResourceId:(NSString*)resourceId
{
    [self inflateRootWithLocalResourceId:resourceId forRegion:nil];
}

- (void)initWithLocalResourceId:(NSString*)resourceId
                              forRegion:(OAWorldRegion*)region
{
    [self inflateRootWithLocalResourceId:resourceId forRegion:region];
}


- (void)inflateRootWithLocalResourceId:(NSString*)resourceId
                                      forRegion:(OAWorldRegion*)region
{
    _resourceId = resourceId;
    
    NSMutableArray *tKeys = [NSMutableArray array];
    NSMutableArray *tValues = [NSMutableArray array];
    NSMutableArray *tButtons = [NSMutableArray array];
    
    const auto& resource = [OsmAndApp instance].resourcesManager->getLocalResource(QString::fromNSString(resourceId));
    const auto localResource = std::dynamic_pointer_cast<const OsmAnd::ResourcesManager::LocalResource>(resource);
    if (!resource || !localResource)
        return;
    
    const auto installedResource = std::dynamic_pointer_cast<const OsmAnd::ResourcesManager::InstalledResource>(localResource);

    // Type
    [tKeys addObject:OALocalizedString(@"res_type")];
    [tValues addObject:[OAResourcesBaseViewController resourceTypeLocalized:localResource->type]];

    // Size
    [tKeys addObject:OALocalizedString(@"res_size")];
    [tValues addObject:[NSByteCountFormatter stringFromByteCount:localResource->size countStyle:NSByteCountFormatterCountStyleFile]];

    if (installedResource)
    {
        // Timestamp
        NSDate *d = [NSDate dateWithTimeIntervalSince1970:installedResource->timestamp / 1000];
        
        if (!formatter) {
            formatter = [[NSDateFormatter alloc] init];
            [formatter setDateStyle:NSDateFormatterShortStyle];
            [formatter setTimeStyle:NSDateFormatterShortStyle];
        }

        NSString *dateStr = [formatter stringFromDate:d];
        if (dateStr.length > 0)
        {
            [tKeys addObject:OALocalizedString(@"res_created_on")];
            [tValues addObject:[NSString stringWithFormat:@"%@", dateStr]];
        }
        [tButtons addObject:[self getButtonCell:(NSString *)@"delete"]];
    }
    
    tableKeys = tKeys;
    tableValues = tValues;
    tableButtons = tButtons;
}

- (OAButtonCell *) getButtonCell:(NSString *)type
{
    static NSString* const identifierCell = @"OAButtonCell";
    OAButtonCell* cell = nil;
    
    cell = [self.tableView dequeueReusableCellWithIdentifier:identifierCell];
    if (cell == nil)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OAButtonCell" owner:self options:nil];
        cell = (OAButtonCell *)[nib objectAtIndex:0];
    }
    if (cell)
    {
        if ([type isEqual:@"delete"])
        {
            [cell.button setTitle:OALocalizedString(@"shared_string_delete") forState:UIControlStateNormal];
            [cell.button addTarget:self action:@selector(deleteClicked) forControlEvents:UIControlEventTouchDown];
        }
        else if ([type isEqual:@"clear_cache"])
        {
            [cell.button setTitle:OALocalizedString(@"shared_string_clear_cache") forState:UIControlStateNormal];
            [cell.button addTarget:self action:@selector(clearCacheClicked) forControlEvents:UIControlEventTouchDown];
        }
        [cell showImage:NO];
    }
    return cell;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return tableKeys.count;
    else
        return tableButtons.count;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
        return OALocalizedStringUp(@"res_details");
    else
        return OALocalizedStringUp(@"actions");
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        static NSString* const detailsCell = @"detailsCell";
        
        NSString* title = [tableKeys objectAtIndex:indexPath.row];
        NSString* subtitle = [tableValues objectAtIndex:indexPath.row];
        
        // Obtain reusable cell or create one
        OALocalResourceInfoCell* cell = [tableView dequeueReusableCellWithIdentifier:detailsCell];
        if (cell == nil)
        {
            cell = [[OALocalResourceInfoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:detailsCell];
        }
            
        // Fill cell content
        cell.leftLabelView.text = title;
        cell.rightLabelView.text = subtitle;
        
        return cell;
    }
    else
    {
        return tableButtons[indexPath.row];
    }
}

#pragma mark - UITableViewDelegate

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (IBAction)btnToolbarMapsClicked:(id)sender
{
}

- (IBAction)btnToolbarPluginsClicked:(id)sender
{
    OAPluginsViewController *pluginsViewController = [[OAPluginsViewController alloc] init];
    pluginsViewController.openFromSplash = _openFromSplash;
    [self.navigationController pushViewController:pluginsViewController animated:NO];
}

- (IBAction)btnToolbarPurchasesClicked:(id)sender
{
    OAPurchasesViewController *purchasesViewController = [[OAPurchasesViewController alloc] init];
    purchasesViewController.openFromSplash = _openFromSplash;
    [self.navigationController pushViewController:purchasesViewController animated:NO];
}

@end
