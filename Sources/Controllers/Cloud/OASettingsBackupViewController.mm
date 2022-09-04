//
//  OASettingsBackupViewController.mm
//  OsmAnd Maps
//
//  Created by Skalii on 20.08.2022.
//  Copyright (c) 2022 OsmAnd. All rights reserved.
//

#import "OASettingsBackupViewController.h"
#import "OACloudAccountLogoutViewController.h"
#import "OADeleteAllVersionsBackupViewController.h"
#import "OAMainSettingsViewController.h"
#import "OABaseBackupTypesViewController.h"
#import "OABackupTypesViewController.h"
#import "OAMenuSimpleCell.h"
#import "OATitleRightIconCell.h"
#import "OAAppSettings.h"
#import "OABackupHelper.h"
#import "OAPrepareBackupResult.h"
#import "OAColors.h"
#import "Localization.h"

@interface OASettingsBackupViewController () <UITableViewDelegate, UITableViewDataSource, OACloudAccountLogoutDelegate, OADeleteAllVersionsBackupDelegate, OABackupTypesDelegate, OAOnDeleteFilesListener, OAOnPrepareBackupListener>

@property (weak, nonatomic) IBOutlet UIView *navigationBarView;
@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation OASettingsBackupViewController
{
    NSMutableArray<NSMutableDictionary *> *_data;
    OABackupHelper *_backupHelper;
    NSDictionary<NSString *, OARemoteFile *> *_uniqueRemoteFiles;

    NSIndexPath *_backupDataIndexPath;
    NSInteger _progressFilesCompleteCount;
    NSInteger _progressFilesTotalCount;
    BOOL _needUpdateBackupDataCell;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    _backupHelper = [OABackupHelper sharedInstance];
    _uniqueRemoteFiles = [_backupHelper.backup getRemoteFiles:EOARemoteFilesTypeUnique];
    _progressFilesCompleteCount = 0;
    _progressFilesTotalCount = 1;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    [self setupView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_backupHelper addPrepareBackupListener:self];
    if (![_backupHelper isBackupPreparing])
        [self onBackupPrepared:_backupHelper.backup];
    [_backupHelper.backupListeners addDeleteFilesListener:self];

    [self updateAfterDeleted];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [_backupHelper removePrepareBackupListener:self];
    [_backupHelper.backupListeners removeDeleteFilesListener:self];
}

- (void)applyLocalization
{
    [super applyLocalization];
    self.titleLabel.text = OALocalizedString(@"shared_string_settings");
}

- (void)setupView
{
    NSMutableArray *data = [NSMutableArray array];

    NSMutableArray<NSMutableDictionary *> *osmAndCloudCells = [NSMutableArray array];
    NSMutableDictionary *osmAndCloudSection = [NSMutableDictionary dictionary];
    osmAndCloudSection[@"header"] = OALocalizedString(@"osmand_cloud");
    osmAndCloudSection[@"footer"] = OALocalizedString(@"select_backup_data_descr");
    osmAndCloudSection[@"cells"] = osmAndCloudCells;
    [data addObject:osmAndCloudSection];

    NSMutableDictionary *backupData = [NSMutableDictionary dictionary];
    backupData[@"key"] = @"backup_data_cell";
    backupData[@"type"] = [OAMenuSimpleCell getCellIdentifier];
    backupData[@"title"] = OALocalizedString(@"backup_data");
    backupData[@"icon"] = @"ic_custom_cloud_upload_colored_day";
    NSString *sizeBackupDataString = [NSByteCountFormatter stringFromByteCount:
            [OABaseBackupTypesViewController calculateItemsSize:_uniqueRemoteFiles.allValues]
                                                     countStyle:NSByteCountFormatterCountStyleFile];
    backupData[@"description"] = sizeBackupDataString;
    [osmAndCloudCells addObject:backupData];
    _backupDataIndexPath = [NSIndexPath indexPathForRow:[osmAndCloudCells indexOfObject:backupData]
                                              inSection:[data indexOfObject:osmAndCloudSection]];

    NSMutableArray<NSMutableDictionary *> *accountCells = [NSMutableArray array];
    NSMutableDictionary *accountSection = [NSMutableDictionary dictionary];
    accountSection[@"header"] = OALocalizedString(@"shared_string_account");
    accountSection[@"cells"] = accountCells;
    [data addObject:accountSection];

    NSMutableDictionary *accountData = [NSMutableDictionary dictionary];
    accountData[@"key"] = @"account_cell";
    accountData[@"type"] = [OATitleRightIconCell getCellIdentifier];
    accountData[@"title"] = [[OAAppSettings sharedManager].backupUserEmail get];
    accountData[@"text_color"] = UIColor.blackColor;
    [accountCells addObject:accountData];

    NSMutableArray<NSMutableDictionary *> *dangerZoneCells = [NSMutableArray array];
    NSMutableDictionary *dangerZoneSection = [NSMutableDictionary dictionary];
    dangerZoneSection[@"header"] = OALocalizedString(@"backup_danger_zone");
    dangerZoneSection[@"footer"] = OALocalizedString(@"backup_delete_all_data_or_versions_descr");
    dangerZoneSection[@"cells"] = dangerZoneCells;
    [data addObject:dangerZoneSection];

    NSMutableDictionary *deleteAllData = [NSMutableDictionary dictionary];
    deleteAllData[@"key"] = @"delete_all_cell";
    deleteAllData[@"type"] = [OATitleRightIconCell getCellIdentifier];
    deleteAllData[@"title"] = OALocalizedString(@"backup_delete_all_data");
    deleteAllData[@"text_color"] = UIColorFromRGB(color_support_red);
    [dangerZoneCells addObject:deleteAllData];

    NSMutableDictionary *removeVersionsData = [NSMutableDictionary dictionary];
    removeVersionsData[@"key"] = @"remove_versions_cell";
    removeVersionsData[@"type"] = [OATitleRightIconCell getCellIdentifier];
    removeVersionsData[@"title"] = OALocalizedString(@"backup_delete_old_data");
    removeVersionsData[@"text_color"] = UIColorFromRGB(color_support_red);
    [dangerZoneCells addObject:removeVersionsData];

    _data = data;
}

- (NSMutableDictionary *)getItem:(NSIndexPath *)indexPath
{
    return _data[indexPath.section][@"cells"][indexPath.row];
}

- (void)updateAfterDeleted
{
    if (_needUpdateBackupDataCell && _backupDataIndexPath)
    {
        NSString *sizeBackupDataString = [NSByteCountFormatter stringFromByteCount:
                [OABaseBackupTypesViewController calculateItemsSize:_uniqueRemoteFiles.allValues]
                                                                        countStyle:NSByteCountFormatterCountStyleFile];
        NSArray *cells = ((NSArray *) _data[_backupDataIndexPath.section][@"cells"]);
        ((NSMutableDictionary *) cells[_backupDataIndexPath.row])[@"description"] = sizeBackupDataString;
        [UIView performWithoutAnimation:^{
            [self.tableView reloadRowsAtIndexPaths:@[_backupDataIndexPath]
                                  withRowAnimation:UITableViewRowAnimationNone];
        }];

        _needUpdateBackupDataCell = NO;
        if (self.backupTypesDelegate)
            [self.backupTypesDelegate onAllFilesDeleted];
    }
}

- (IBAction)backButtonClicked:(id)sender
{
    [self dismissViewController];
}

#pragma mark - OACloudAccountLogoutDelegate

- (void)onLogout
{
    [[OABackupHelper sharedInstance] logout];

    for (UIViewController *controller in self.navigationController.viewControllers)
    {
        if ([controller isKindOfClass:OAMainSettingsViewController.class])
        {
            [self.navigationController popToViewController:controller animated:YES];
            return;
        }
    }

    [self dismissViewController];
}

#pragma mark - OADeleteAllVersionsBackupDelegate

- (void)onCloseDeleteAllBackupData
{
}

- (void)onAllFilesDeleted
{
    _needUpdateBackupDataCell = YES;
    [_backupHelper prepareBackup];
}

#pragma mark - OABackupTypesDelegate

- (void)setProgressTotal:(NSInteger)total
{
    _progressFilesTotalCount = total;
}

#pragma mark - OAOnDeleteFilesListener

- (void)onFilesDeleteStarted:(NSArray<OARemoteFile *> *)files
{
    _progressFilesTotalCount = files.count;
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            [self.progressView setProgress:0.0 animated:NO];
            self.progressView.hidden = NO;
        }];
    });
}

- (void)onFileDeleteProgress:(OARemoteFile *)file progress:(NSInteger)progress
{
    _progressFilesCompleteCount = progress;
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            if (self.progressView.hidden)
                self.progressView.hidden = NO;

            float progressValue = (float) _progressFilesCompleteCount / _progressFilesTotalCount;
            [self.progressView setProgress:progressValue animated:YES];
        }];
    });
}

- (void)onFilesDeleteDone:(NSDictionary<OARemoteFile *, NSString *> *)errors
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            [self.progressView setProgress:1.0 animated:YES];
        } completion:^(BOOL finished) {
            self.progressView.hidden = YES;
            [_backupHelper prepareBackup];
            _progressFilesCompleteCount = 0;
            _progressFilesTotalCount = 1;
        }];
    });
}

- (void) onFilesDeleteError:(NSInteger)status message:(NSString *)message
{
    [_backupHelper prepareBackup];
    _progressFilesCompleteCount = 0;
    _progressFilesTotalCount = 1;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressView setProgress:_progressFilesCompleteCount animated:NO];
    });
}

#pragma mark - OAOnPrepareBackupListener

- (void)onBackupPreparing
{
    [UIView animateWithDuration:0.3 animations:^{
        [self.progressView setProgress:0.1 animated:NO];
        self.progressView.hidden = NO;
    }];
}

- (void)onBackupPrepared:(OAPrepareBackupResult *)backupResult
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            [self.progressView setProgress:1.0 animated:YES];
            _uniqueRemoteFiles = [backupResult getRemoteFiles:EOARemoteFilesTypeUnique];
            [self updateAfterDeleted];
        } completion:^(BOOL finished) {
            self.progressView.hidden = YES;
        }];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _data.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return ((NSArray *) _data[section][@"cells"]).count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    NSString *cellType = item[@"type"];
    UITableViewCell *outCell = nil;

    if ([cellType isEqualToString:[OAMenuSimpleCell getCellIdentifier]])
    {
        OAMenuSimpleCell *cell = [tableView dequeueReusableCellWithIdentifier:[OAMenuSimpleCell getCellIdentifier]];
        if (!cell)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAMenuSimpleCell getCellIdentifier] owner:self options:nil];
            cell = (OAMenuSimpleCell *) nib[0];
            cell.separatorInset = UIEdgeInsetsMake(0., 66., 0., 0.);
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.descriptionView.textColor = UIColorFromRGB(color_text_footer);
            [cell changeHeight:YES];
        }
        if (cell)
        {
            cell.imgView.image = [UIImage imageNamed:item[@"icon"]];
            cell.textView.text = item[@"title"];
            cell.descriptionView.text = item[@"description"];
        }
        outCell = cell;
    }
    else if ([cellType isEqualToString:[OATitleRightIconCell getCellIdentifier]])
    {
        OATitleRightIconCell *cell = [tableView dequeueReusableCellWithIdentifier:[OATitleRightIconCell getCellIdentifier]];
        if (!cell)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OATitleRightIconCell getCellIdentifier] owner:self options:nil];
            cell = (OATitleRightIconCell *) nib[0];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.separatorInset = UIEdgeInsetsMake(0., 20., 0., 0.);
            [cell setIconVisibility:NO];
        }
        if (cell)
        {
            cell.titleView.text = item[@"title"];
            cell.titleView.textColor = item[@"text_color"];
        }
        outCell =  cell;
    }

    [outCell updateConstraintsIfNeeded];
    return outCell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return _data[section][@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return _data[section][@"footer"];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    NSString *key = item[@"key"];

    if ([key isEqualToString:@"backup_data_cell"])
    {
        OABackupTypesViewController *backupDataController = [[OABackupTypesViewController alloc] init];
        backupDataController.backupTypesDelegate = self;
        [self.navigationController pushViewController:backupDataController animated:YES];
    }
    else if ([key isEqualToString:@"account_cell"])
    {
        OACloudAccountLogoutViewController *logoutViewController = [[OACloudAccountLogoutViewController alloc] init];
        logoutViewController.logoutDelegate = self;
        [self presentViewController:logoutViewController animated:YES completion:nil];
    }
    else if ([key isEqualToString:@"delete_all_cell"])
    {
        OADeleteAllVersionsBackupViewController *deleteAllDataViewController = [[OADeleteAllVersionsBackupViewController alloc] initWithScreenType:EOADeleteAllDataBackupScreenType];
        deleteAllDataViewController.deleteDelegate = self;
        [self.navigationController pushViewController:deleteAllDataViewController animated:YES];
    }
    else if ([key isEqualToString:@"remove_versions_cell"])
    {
        OADeleteAllVersionsBackupViewController *removeOldVersionsViewController = [[OADeleteAllVersionsBackupViewController alloc] initWithScreenType:EOARemoveOldVersionsBackupScreenType];
        removeOldVersionsViewController.deleteDelegate = self;
        [self.navigationController pushViewController:removeOldVersionsViewController animated:YES];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end