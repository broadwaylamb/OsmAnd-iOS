//
//  OAWikiWebViewController.m
//  OsmAnd
//
//  Created by Alexey Kulish on 04/06/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAWikiWebViewController.h"
#import "OAWikiLanguagesWebViewContoller.h"
#import "OARootViewController.h"
#import "OATableDataModel.h"
#import "OATableSectionData.h"
#import "OATableRowData.h"
#import "OAAppSettings.h"
#import "OADownloadMode.h"
#import "OAPlugin.h"
#import "OAPOI.h"
#import "OsmAndApp.h"
#import "OASizes.h"
#import "Localization.h"
#import "OAWikiArticleHelper.h"
#import <SafariServices/SafariServices.h>
#import <AFNetworking/AFNetworkReachabilityManager.h>
#import "OsmAnd_Maps-Swift.h"

#define kHeaderImageHeight 170

@interface OAWikiWebViewController () <SFSafariViewControllerDelegate, OAWikiLanguagesWebDelegate>

@end

@implementation OAWikiWebViewController
{
    OsmAndAppInstance _app;
    OAPOI *_poi;
    NSLocale *_currentLocale;
    NSString *_contentLocale;
    NSString *_content;
    OATableDataModel *_data;
    UIBarButtonItem *_languageBarButtonItem;
    UIBarButtonItem *_imagesBarButtonItem;
    BOOL _isDownloadImagesOnlyNow;
    BOOL _isFirstLaunch;
}

#pragma mark - Initialization

- (instancetype)initWithPoi:(OAPOI *)poi
{
    self = [super init];
    if (self)
    {
        _isFirstLaunch = YES;
        _poi = poi;
        _currentLocale = nil;
        _contentLocale = nil;
        [self postInit];
    }
    return self;
}

- (instancetype)initWithPoi:(OAPOI *)poi locale:(NSString *)locale
{
    self = [self initWithPoi:poi];
    if (self)
    {
        _currentLocale = [NSLocale localeWithLocaleIdentifier:locale];
        _contentLocale = [locale isEqualToString:@"en"] ? @"" : locale;
        [self postInit];
    }
    return self;
}

- (void)commonInit
{
    _app = [OsmAndApp instance];
}

- (void) updateWithPoi:(OAPOI *)poi
{
    _poi = poi;
    [self postInit];
}

- (void)postInit
{
    if (!_currentLocale)
    {
        NSLocale *currentLocal = [NSLocale autoupdatingCurrentLocale];
        id localIdentifier = [currentLocal objectForKey:NSLocaleIdentifier];
        _currentLocale = [NSLocale localeWithLocaleIdentifier:localIdentifier];
    }

    if (_poi.localizedContent.count == 1)
    {
        _contentLocale = _poi.localizedContent.allKeys.firstObject;
        _content = _poi.localizedContent.allValues.firstObject;
    }
    else
    {
        if (!_contentLocale)
        {
            NSString *preferredMapLanguage = [[OAAppSettings sharedManager] settingPrefMapLanguage].get;
            if (!preferredMapLanguage || preferredMapLanguage.length == 0)
                preferredMapLanguage = NSLocale.currentLocale.languageCode;
            
            _contentLocale = [OAPlugin onGetMapObjectsLocale:_poi preferredLocale:preferredMapLanguage];
            if ([_contentLocale isEqualToString:@"en"])
                _contentLocale = @"";
        }

        _content = _poi.localizedContent[_contentLocale];
        if (!_content)
        {
            NSArray<NSString *> *contentLocales = _poi.localizedContent.allKeys;
            NSMutableSet<NSString *> *preferredLocales = [NSMutableSet set];
            NSArray<NSString *> *preferredLanguages = [NSLocale preferredLanguages];
            for (NSInteger i = 0; i < preferredLanguages.count; i ++)
            {
                NSString *preferredLocale = preferredLanguages[i];
                if ([preferredLocale containsString:@"-"])
                    preferredLocale = [preferredLocale substringToIndex:[preferredLocale indexOf:@"-"]];
                if ([preferredLocale isEqualToString:@"en"])
                    preferredLocale = @"";
                [preferredLocales addObject:preferredLocale];
            }

            for (NSString *preferredLocale in preferredLocales)
            {
                if ([contentLocales containsObject:preferredLocale])
                {
                    _contentLocale = preferredLocale;
                    _content = _poi.localizedContent[_contentLocale];
                    break;
                }
            }

            if (!_content)
            {
                _contentLocale = _poi.localizedContent.allKeys.firstObject;
                _content = _poi.localizedContent[_contentLocale];
            }
        }
    }

    if (_content)
        _content = [self appendHeadToContent:_content];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSString *newUrl = [OAWikiArticleHelper normalizeFileUrl:[navigationAction.request.URL.absoluteString stringByRemovingPercentEncoding]];
    NSString *currentUrl = [OAWikiArticleHelper normalizeFileUrl:[webView.URL.absoluteString stringByRemovingPercentEncoding]];
    NSInteger wikiUrlEndDndex = [currentUrl indexOf:@"#"];
    if (wikiUrlEndDndex > 0)
        currentUrl = [currentUrl substringToIndex:[currentUrl indexOf:@"#"]];
    
    if (_isFirstLaunch)
    {
        _isFirstLaunch = NO;
        decisionHandler(WKNavigationActionPolicyAllow);
    }
    else
    {
        if ([newUrl hasPrefix:currentUrl])
        {
            //Navigation inside one page by anchors
            decisionHandler(WKNavigationActionPolicyAllow);
        }
        else
        {
            //New url
            if (([newUrl containsString:kWikiDomain] || [newUrl containsString:kWikiDomainCom]) && _poi)
            {
                __block UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:[OALocalizedString(@"wiki_article_search_text") stringByAppendingString:@"\n\n"] preferredStyle:UIAlertControllerStyleAlert];
                UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
                spinner.color = [UIColor blackColor];
                spinner.translatesAutoresizingMaskIntoConstraints = NO;
                spinner.tag = -998;
                [alert.view addSubview:spinner];
                NSDictionary * views = @{@"pending" : alert.view, @"indicator" : spinner};
                NSArray * constraintsVertical = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[indicator]-(20)-|" options:0 metrics:nil views:views];
                NSArray * constraintsHorizontal = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[indicator]|" options:0 metrics:nil views:views];
                NSArray * constraints = [constraintsVertical arrayByAddingObjectsFromArray:constraintsHorizontal];
                [alert.view addConstraints:constraints];
                [spinner setUserInteractionEnabled:NO];
                
                _content = nil;
                [OAWikiArticleHelper showWikiArticle:@[[[CLLocation alloc] initWithLatitude:_poi.latitude longitude:_poi.longitude]] url:newUrl onStart:^{
                    [spinner startAnimating];
                    [self presentViewController:alert animated:YES completion:nil];
                } sourceView:nil sourceFrame:CGRectZero onComplete:^{
                    [alert.view removeSpinner];
                    [alert dismissViewControllerAnimated:YES completion:nil];
                    alert = nil;
                }];
                decisionHandler(WKNavigationActionPolicyCancel);
            }
            else if ([newUrl hasPrefix:kPagePrefixHttp] || [newUrl hasPrefix:kPagePrefixHttps])
            {
                [OAWikiArticleHelper warnAboutExternalLoad:newUrl];
                decisionHandler(WKNavigationActionPolicyCancel);
            }
            else
            {
                decisionHandler(WKNavigationActionPolicyAllow);
                //Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                //AndroidUtils.startActivityIfSafe(context, intent);
            }
        }
    }
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [self createLanguagesNavbarButton];
    [self createImagesNavbarButton];
    [super viewDidLoad];
}

#pragma mark - Base setup UI

- (void)addAccessibilityLabels
{
    _languageBarButtonItem.accessibilityLabel = OALocalizedString(@"select_language");
}

#pragma mark - Base UI

- (NSString *)getTitle
{
    return _poi.localizedNames[_contentLocale] ? _poi.localizedNames[_contentLocale] : OALocalizedString(@"download_wikipedia_maps");
}

- (void)createLanguagesNavbarButton
{
    UIMenu *languageMenu;
    NSMutableArray<UIMenuElement *> *languageOptions = [NSMutableArray array];
    if (_poi.localizedContent.allKeys.count > 1)
    {
        NSMutableSet<NSString *> *preferredLocales = [NSMutableSet set];
        NSArray<NSString *> *preferredLanguages = [NSLocale preferredLanguages];
        for (NSInteger i = 0; i < preferredLanguages.count; i ++)
        {
            NSString *preferredLocale = preferredLanguages[i];
            if ([preferredLocale containsString:@"-"])
                preferredLocale = [preferredLocale substringToIndex:[preferredLocale indexOf:@"-"]];
            if ([preferredLocale isEqualToString:@"en"])
                preferredLocale = @"";
            [preferredLocales addObject:preferredLocale];
        }

        NSMutableArray<NSString *> *possibleAvailableLocale = [NSMutableArray array];
        NSMutableArray<NSString *> *possiblePreferredLocale = [NSMutableArray array];
        for (NSString *contentLocale in _poi.localizedContent.allKeys)
        {
            if ([preferredLocales containsObject:contentLocale])
            {
                UIAction *languageAction = [UIAction actionWithTitle:[OAUtilities translatedLangName:contentLocale.length > 0 ? contentLocale : @"en"].capitalizedString
                                                       image:nil
                                                  identifier:nil
                                                     handler:^(__kindof UIAction * _Nonnull action) {
                    [self updateWikiData:contentLocale];
                }];
                if ([contentLocale isEqualToString:_contentLocale])
                    languageAction.state = UIMenuElementStateOn;
                [languageOptions addObject:languageAction];
                [possiblePreferredLocale addObject:contentLocale];
            }
            else
            {
                [possibleAvailableLocale addObject:contentLocale];
            }
        }
        if (possibleAvailableLocale.count > 0)
        {
            UIAction *availableLanguagesAction = [UIAction actionWithTitle:OALocalizedString(@"available_languages")
                                                                     image:[UIImage systemImageNamed:@"globe"]
                                                                identifier:nil
                                                                   handler:^(__kindof UIAction * _Nonnull action) {
                OAWikiLanguagesWebViewContoller *wikiLanguagesViewController =
                            [[OAWikiLanguagesWebViewContoller alloc] initWithSelectedLocale:_contentLocale
                                                                           availableLocales:possibleAvailableLocale
                                                                           preferredLocales:possiblePreferredLocale];
                wikiLanguagesViewController.delegate = self;
                [self showModalViewController:wikiLanguagesViewController];
            }];
            if (![preferredLocales containsObject:_contentLocale])
                availableLanguagesAction.state = UIMenuElementStateOn;
            UIMenu *availableLanguagesMenu = [UIMenu menuWithTitle:@""
                                                             image:nil
                                                        identifier:nil
                                                           options:UIMenuOptionsDisplayInline
                                                          children:@[availableLanguagesAction]];
            [languageOptions addObject:availableLanguagesMenu];
        }
        languageMenu = [UIMenu menuWithChildren:languageOptions];
    }
    _languageBarButtonItem = [self createRightNavbarButton:nil iconName:@"ic_navbar_languge" action:@selector(onLanguageNavbarButtonPressed) menu:languageMenu];
}

- (void)createImagesNavbarButton
{
    NSMutableArray<UIMenuElement *> *downloadModeOptions = [NSMutableArray array];
    NSString *selectedIconName = @"ic_navbar_image_disabled_outlined";
    NSArray<OADownloadMode *> *downloadModes = [OADownloadMode getDownloadModes];
    for (OADownloadMode *downloadMode in downloadModes)
    {
        UIAction *downloadModeAction = [UIAction actionWithTitle:downloadMode.title
                                                           image:nil
                                                      identifier:nil
                                                         handler:^(__kindof UIAction * _Nonnull action) {
            _app.data.wikipediaImagesDownloadMode = downloadMode;
            [self updateWikiData];
        }];
        if ([downloadMode isEqual:_app.data.wikipediaImagesDownloadMode])
        {
            downloadModeAction.state = _isDownloadImagesOnlyNow ? UIMenuElementStateMixed : UIMenuElementStateOn;
            selectedIconName = downloadMode.iconName;
        }
        [downloadModeOptions addObject:downloadModeAction];
    }

    UIAction *downloadOnlyNowModeAction = [UIAction actionWithTitle:OALocalizedString(@"download_only_now")
                                                              image:[UIImage systemImageNamed:@"square.and.arrow.down"]
                                                         identifier:nil
                                                            handler:^(__kindof UIAction * _Nonnull action) {
                                    OADownloadMode *imagesDownloadMode = [self getImagesDownloadMode];
                                    if ([[AFNetworkReachabilityManager sharedManager] isReachableViaWWAN] && ([imagesDownloadMode isDontDownload] || [imagesDownloadMode isDownloadOnlyViaWifi]))
                                    {
                                        UIAlertController *alert =
                                            [UIAlertController alertControllerWithTitle:OALocalizedString(@"wikivoyage_download_pics")
                                                                                message:OALocalizedString(@"download_over_cellular_network")
                                                                         preferredStyle:UIAlertControllerStyleAlert];
                                            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:OALocalizedString(@"shared_string_cancel")
                                                                                                   style:UIAlertActionStyleDefault
                                                                                                 handler:nil];
                                            UIAlertAction *downloadAction = [UIAlertAction actionWithTitle:OALocalizedString(@"shared_string_download")
                                                                                                     style:UIAlertActionStyleDefault
                                                                                                   handler:^(UIAlertAction * _Nonnull action) {
                                                _isDownloadImagesOnlyNow = YES;
                                                [self updateWikiData];
                                            }];
                                        [alert addAction:cancelAction];
                                        [alert addAction:downloadAction];
                                        alert.preferredAction = downloadAction;
                                        [self presentViewController:alert animated:YES completion:nil];
                                   }
                                   else if ([[AFNetworkReachabilityManager sharedManager] isReachableViaWiFi])
                                   {
                                       _isDownloadImagesOnlyNow = YES;
                                       [self updateWikiData];
                                   }
    }];
    if (_isDownloadImagesOnlyNow)
        downloadOnlyNowModeAction.state = UIMenuElementStateOn;
    UIMenu *downloadModeOnlyNow = [UIMenu menuWithTitle:@""
                                                  image:nil
                                             identifier:nil
                                                options:UIMenuOptionsDisplayInline
                                               children:@[downloadOnlyNowModeAction]];
    [downloadModeOptions addObject:downloadModeOnlyNow];

    _imagesBarButtonItem = [self createRightNavbarButton:nil
                                                iconName:selectedIconName
                                                  action:@selector(onImagesNavbarButtonPressed)
                                                    menu:[UIMenu menuWithChildren:downloadModeOptions]];
}

- (NSArray<UIBarButtonItem *> *)getRightNavbarButtons
{
    return @[_imagesBarButtonItem, _languageBarButtonItem];
}

- (EOABaseNavbarStyle)getNavbarStyle
{
    return EOABaseNavbarStyleCustomLargeTitle;
}

- (void)setupCustomLargeTitleView
{
}

- (UILayoutConstraintAxis)getBottomAxisMode
{
    return UILayoutConstraintAxisHorizontal;
}

- (NSString *)getTopButtonIconName
{
    return @"ic_custom_export_outlined";
}

- (NSString *)getBottomButtonIconName
{
    return @"ic_custom_safari";
}

- (EOABaseButtonColorScheme)getTopButtonColorScheme
{
    return EOABaseButtonColorSchemeGraySimple;
}

#pragma mark - Web Data

- (NSURL *)getUrl
{
    NSString *locale = _contentLocale.length == 0 ? @"en" : _contentLocale;
    NSString *wikipediaTitle = [self getWikipediaTitleURL];
    NSString *wikiUrl = [OAWikiAlgorithms getWikiUrlWithText:[NSString stringWithFormat:@"%@:%@", locale, wikipediaTitle]];
    return [NSURL URLWithString:wikiUrl];
}

- (NSString *)getContent
{
    return _content;
}

- (OADownloadMode *)getImagesDownloadMode
{
    return _app.data.wikipediaImagesDownloadMode;
}

- (BOOL)isDownloadImagesOnlyNow
{
    return _isDownloadImagesOnlyNow;
}

- (void)resetDownloadImagesOnlyNow
{
    _isDownloadImagesOnlyNow = NO;
}

#pragma mark - Web load

- (void)loadHeaderImage:(void(^)(NSString *content))loadWebView
{
    OADownloadMode *imagesDownloadMode = [self getImagesDownloadMode];
    if (![self isDownloadImagesOnlyNow] && ([imagesDownloadMode isDontDownload] || ([imagesDownloadMode isDownloadOnlyViaWifi] && [[AFNetworkReachabilityManager sharedManager] isReachableViaWWAN])))
    {
        if (loadWebView)
            loadWebView([self getContent]);
    }
    else
    {
        NSString *locale = _contentLocale.length == 0 ? @"en" : _contentLocale;
        NSString *wikipediaTitle = [self getWikipediaTitleURL];
        NSString *titleImageLink = [NSString stringWithFormat:@"https://%@.wikipedia.org/w/api.php?action=query&titles=%@&prop=pageimages&format=json&pithumbsize=%lu",
                                    locale,
                                    wikipediaTitle,
                                    (NSInteger) self.view.frame.size.width];
        NSURL *titleImageURL = [NSURL URLWithString:titleImageLink];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        [[session dataTaskWithURL:titleImageURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSString *content = [self getContent];
            NSString *imageSource = @"";
            if (((NSHTTPURLResponse *) response).statusCode == 200 && data)
            {
                if (data)
                {
                    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                    if ([result.allKeys containsObject:@"query"])
                    {
                        NSDictionary *queryResult = result[@"query"];
                        if ([queryResult.allKeys containsObject:@"pages"])
                        {
                            NSDictionary *pagesResult = queryResult[@"pages"];
                            if (pagesResult.allKeys.count > 0)
                            {
                                NSDictionary *sourceResult = pagesResult[pagesResult.allKeys.firstObject];
                                if ([sourceResult.allKeys containsObject:@"thumbnail"])
                                {
                                    NSDictionary *thumbnailResult = sourceResult[@"thumbnail"];
                                    imageSource = thumbnailResult[@"source"];
                                }
                            }
                        }
                    }
                }
                if (imageSource && imageSource.length > 0)
                {
                    content = [content stringByReplacingOccurrencesOfString:@"</header>"
                                                                 withString:[NSString stringWithFormat:@"<img src=%@ style=\"object-fit:cover; object-position:center; height:%dpx;\"></header>", imageSource, kHeaderImageHeight]];
                }
            }
            if (loadWebView)
                loadWebView(content);
        }] resume];
    }
}

#pragma mark - Selectors

- (void)onLanguageNavbarButtonPressed
{
    if (_poi.localizedContent.allKeys.count <= 1)
    {
        [OARootViewController showInfoAlertWithTitle:nil
                                             message:OALocalizedString(@"no_other_translations")
                                        inController:self];
        return;
    }
}

- (void)onImagesNavbarButtonPressed
{
}

- (void)onTopButtonPressed
{
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[[self getUrl]]
                                                                                         applicationActivities:nil];
    activityViewController.popoverPresentationController.sourceView = self.view;
    activityViewController.popoverPresentationController.sourceRect = self.topButton.frame;
    [self.navigationController presentViewController:activityViewController animated:YES completion:nil];
}

- (void)onBottomButtonPressed
{
    NSURL *url = [self getUrl];
    if (url)
    {
        SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url];
        [self presentViewController:safariViewController animated:YES completion:nil];
    }
}

#pragma mark - UIScrollViewDelegate

- (CGFloat)getCustomTitleHeaderTopOffset
{
    OADownloadMode *imagesDownloadMode = [self getImagesDownloadMode];
    if (![self isDownloadImagesOnlyNow] && ([imagesDownloadMode isDontDownload] || ([imagesDownloadMode isDownloadOnlyViaWifi] && [[AFNetworkReachabilityManager sharedManager] isReachableViaWWAN])))
        return 0.;

    return kHeaderImageHeight;
}

#pragma mark - Additions

- (NSString *)getWikipediaTitleURL
{
    NSString *title = [self getTitle];
    BOOL hasLocalizedName = ![title isEqualToString:OALocalizedString(@"download_wikipedia_maps")];
    return !hasLocalizedName ? @"" : [[title stringByReplacingOccurrencesOfString:@" "
                                                                       withString:@"_"]
                                      stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
}

- (void)updateWikiData
{
    [self updateWikiData:_contentLocale];
}

- (void)updateWikiData:(NSString *)locale
{
    NSString *content = [self appendHeadToContent:_poi.localizedContent[locale]];
    if (content)
    {
        _contentLocale = locale;
        _content = content;
        [self createLanguagesNavbarButton];
        [self createImagesNavbarButton];
        [UIView transitionWithView:self.view
                          duration:.2
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^(void)
                        {
                            [self updateNavbar];
                            [self applyLocalization];
                            [self loadWebView];
                        }
                        completion:nil];
    }
}

- (NSString *)appendHeadToContent:(NSString *)content
{
    if (content == nil)
        return nil;

    NSString *head = @"<header><meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no'></header><head></head><div class=\"main\">%@</div>";
    return [NSString stringWithFormat:head, content];
}

#pragma mark - WebView

- (void)webViewDidCommitted:(void(^)(void))onViewCommitted
{
    BOOL containsRTL = [[OAAppSettings sharedManager].rtlLanguages containsObject:_contentLocale];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"article_style" ofType:@"css"];
    NSString *cssContents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    cssContents = [cssContents stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *javascriptWithCSSString = [NSString stringWithFormat:kLargeTitleJS, cssContents, [[self getTitle] stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]];
    [self.webView evaluateJavaScript:kCollapseJS completionHandler:nil];
    [self.webView evaluateJavaScript:javascriptWithCSSString completionHandler:^(id _Nullable object, NSError * _Nullable error) {
        if (!containsRTL && onViewCommitted)
            onViewCommitted();
    }];
    if (containsRTL)
        [self.webView evaluateJavaScript:kRtlJS completionHandler:^(id _Nullable object, NSError * _Nullable error) {
            if (onViewCommitted)
                onViewCommitted();
        }];
}

#pragma mark - SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - OAWikiLanguagesWebDelegate

- (void)onLocaleSelected:(NSString *)locale
{
    [self updateWikiData:locale];
}

@end
