//
//  GameShortcutsViewController.m
//  Moonlight
//
//  Created by GameSphere on 6/13/25.
//  Copyright © 2025 Moonlight Stream. All rights reserved.
//

#import "GameShortcutsViewController.h"
#import "GameListManager.h"
#import "TemporaryApp.h"
#import "TemporaryHost.h"
#import "UIAppView.h"
#import "MainFrameViewController.h"
#import "StreamFrameViewController.h"
#import "StreamConfiguration.h"
#import "DataManager.h"
#import "TemporarySettings.h"
#import "AppAssetManager.h"
#import "CryptoManager.h"
#import "IdManager.h"
#import "ControllerSupport.h"
#import "Utils.h"
#import "GameSphereSettingsViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <sys/utsname.h>
#include <Limelight.h>

@interface GameShortcutsViewController () <AppCallback>
@property (nonatomic, strong) NSArray<TemporaryApp *> *games;
@property (nonatomic, strong) NSCache *boxArtCache;
@property (nonatomic, strong) StreamConfiguration *streamConfig;
@end

@implementation GameShortcutsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize cache for box art
    self.boxArtCache = [[NSCache alloc] init];
    
    // Set up collection view
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"GameCell"];
    self.collectionView.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    
    // Set title
    self.title = @"GameSphere";
    
    // Load games from singleton
    [self loadGames];
    
    // Listen for game list updates
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(gamesListUpdated:) 
                                                 name:@"GamesListUpdated" 
                                               object:nil];
    
    // Add refresh button and settings button
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh 
                                                                                   target:self 
                                                                                   action:@selector(refreshGames)];
    
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithTitle:@"Settings" 
                                                                       style:UIBarButtonItemStylePlain 
                                                                      target:self 
                                                                      action:@selector(showSettings)];
    
    self.navigationItem.rightBarButtonItems = @[refreshButton, settingsButton];
}

- (void)loadGames {
    GameListManager *manager = [GameListManager sharedManager];
    self.games = manager.games ?: @[];
    [self.collectionView reloadData];
    
    // Show welcome message if no games
    if (self.games.count == 0) {
        [self showWelcomeMessage];
    } else {
        [self hideWelcomeMessage];
    }
}

- (void)showWelcomeMessage {
    // Remove existing welcome view
    [self hideWelcomeMessage];
    
    UIView *welcomeView = [[UIView alloc] init];
    welcomeView.tag = 999; // Tag for easy removal
    welcomeView.backgroundColor = [UIColor clearColor];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Welcome to GameSphere";
    titleLabel.font = [UIFont boldSystemFontOfSize:24];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    UILabel *messageLabel = [[UILabel alloc] init];
    messageLabel.text = @"Tap 'Moonlight' to connect to your gaming PC\nand discover your games!";
    messageLabel.font = [UIFont systemFontOfSize:16];
    messageLabel.textColor = [UIColor lightGrayColor];
    messageLabel.textAlignment = NSTextAlignmentCenter;
    messageLabel.numberOfLines = 0;
    
    [welcomeView addSubview:titleLabel];
    [welcomeView addSubview:messageLabel];
    [self.view addSubview:welcomeView];
    
    // Auto Layout
    welcomeView.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [welcomeView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [welcomeView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [welcomeView.widthAnchor constraintEqualToConstant:300],
        [welcomeView.heightAnchor constraintEqualToConstant:100],
        
        [titleLabel.topAnchor constraintEqualToAnchor:welcomeView.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:welcomeView.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:welcomeView.trailingAnchor],
        
        [messageLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
        [messageLabel.leadingAnchor constraintEqualToAnchor:welcomeView.leadingAnchor],
        [messageLabel.trailingAnchor constraintEqualToAnchor:welcomeView.trailingAnchor],
        [messageLabel.bottomAnchor constraintEqualToAnchor:welcomeView.bottomAnchor]
    ]];
}

- (void)hideWelcomeMessage {
    UIView *welcomeView = [self.view viewWithTag:999];
    if (welcomeView) {
        [welcomeView removeFromSuperview];
    }
}

- (void)gamesListUpdated:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadGames];
    });
}

- (void)refreshGames {
    // Post notification to trigger a refresh from the main frame
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshGamesRequested" object:nil];
}

- (void)showSettings {
    GameSphereSettingsViewController *settingsVC = [[GameSphereSettingsViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    
    // Style the navigation bar to match the app theme
    navController.navigationBar.barTintColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
    navController.navigationBar.tintColor = [UIColor whiteColor];
    navController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    
    [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.games.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"GameCell" forIndexPath:indexPath];
    
    // Remove any existing subviews
    for (UIView *subview in cell.subviews) {
        [subview removeFromSuperview];
    }
    
    TemporaryApp *app = self.games[indexPath.row];
    UIAppView *appView = [[UIAppView alloc] initWithApp:app cache:self.boxArtCache andCallback:self];
    
    // Scale the app view to fit the cell
    if (appView.bounds.size.width > 10.0) {
        CGFloat scale = cell.bounds.size.width / appView.bounds.size.width;
        [appView setCenter:CGPointMake(appView.bounds.size.width / 2 * scale, appView.bounds.size.height / 2 * scale)];
        appView.transform = CGAffineTransformMakeScale(scale, scale);
    }
    
    [cell addSubview:appView];
    
    // Add shadow
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:cell.bounds];
    cell.layer.masksToBounds = NO;
    cell.layer.shadowColor = [UIColor blackColor].CGColor;
    cell.layer.shadowOffset = CGSizeMake(1.0f, 5.0f);
    cell.layer.shadowPath = shadowPath.CGPath;
    cell.layer.shadowOpacity = 0.3f;
    
#if !TARGET_OS_TV
    cell.layer.borderWidth = 1;
    cell.layer.borderColor = [[UIColor colorWithRed:0 green:0 blue:0 alpha:0.3f] CGColor];
    cell.exclusiveTouch = YES;
#endif
    
    return cell;
}

#pragma mark - UICollectionViewDelegate

#if TARGET_OS_TV
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    TemporaryApp *app = self.games[indexPath.row];
    [self appClicked:app view:nil];
}
#endif

#pragma mark - AppCallback

- (void)appClicked:(TemporaryApp *)app view:(UIView *)view {
    // Prepare stream configuration and launch the game directly
    [self prepareToStreamApp:app];
    [self launchStreamingViewController];
}

- (void)appLongClicked:(TemporaryApp *)app view:(UIView *)view {
    // For now, just treat long clicks as regular clicks
    [self appClicked:app view:view];
}

#pragma mark - Game Launching

- (void)prepareToStreamApp:(TemporaryApp *)app {
    self.streamConfig = [[StreamConfiguration alloc] init];
    self.streamConfig.host = app.host.activeAddress;
    self.streamConfig.httpsPort = app.host.httpsPort;
    self.streamConfig.appID = app.id;
    self.streamConfig.appName = app.name;
    self.streamConfig.serverCert = app.host.serverCert;
    
    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings* streamSettings = [dataMan getSettings];
    
    self.streamConfig.frameRate = [streamSettings.framerate intValue];
    if (@available(iOS 10.3, *)) {
        // Don't stream more FPS than the display can show
        if (self.streamConfig.frameRate > [UIScreen mainScreen].maximumFramesPerSecond) {
            self.streamConfig.frameRate = (int)[UIScreen mainScreen].maximumFramesPerSecond;
            Log(LOG_W, @"Clamping FPS to maximum refresh rate: %d", self.streamConfig.frameRate);
        }
    }
    
    self.streamConfig.height = [streamSettings.height intValue];
    self.streamConfig.width = [streamSettings.width intValue];
#if TARGET_OS_TV
    // Don't allow streaming 4K on the Apple TV HD
    struct utsname systemInfo;
    uname(&systemInfo);
    if (strcmp(systemInfo.machine, "AppleTV5,3") == 0 && self.streamConfig.height >= 2160) {
        Log(LOG_W, @"4K streaming not supported on Apple TV HD");
        self.streamConfig.width = 1920;
        self.streamConfig.height = 1080;
    }
#endif
    
    self.streamConfig.bitRate = [streamSettings.bitrate intValue];
    self.streamConfig.optimizeGameSettings = streamSettings.optimizeGames;
    self.streamConfig.playAudioOnPC = streamSettings.playAudioOnPC;
    self.streamConfig.useFramePacing = streamSettings.useFramePacing;
    self.streamConfig.swapABXYButtons = streamSettings.swapABXYButtons;
    
    // multiController must be set before calling getConnectedGamepadMask
    self.streamConfig.multiController = streamSettings.multiController;
    self.streamConfig.gamepadMask = [ControllerSupport getConnectedGamepadMask:self.streamConfig];
    
    // Probe for supported channel configurations
    int physicalOutputChannels = (int)[AVAudioSession sharedInstance].maximumOutputNumberOfChannels;
    Log(LOG_I, @"Audio device supports %d channels", physicalOutputChannels);
    
    int numberOfChannels = MIN([streamSettings.audioConfig intValue], physicalOutputChannels);
    Log(LOG_I, @"Selected number of audio channels %d", numberOfChannels);
    if (numberOfChannels >= 8) {
        self.streamConfig.audioConfiguration = AUDIO_CONFIGURATION_71_SURROUND;
    }
    else if (numberOfChannels >= 6) {
        self.streamConfig.audioConfiguration = AUDIO_CONFIGURATION_51_SURROUND;
    }
    else {
        self.streamConfig.audioConfiguration = AUDIO_CONFIGURATION_STEREO;
    }
    
    self.streamConfig.serverCodecModeSupport = app.host.serverCodecModeSupport;
    
    switch (streamSettings.preferredCodec) {
        case CODEC_PREF_AV1:
#if defined(__IPHONE_16_0) || defined(__TVOS_16_0)
            if (VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)) {
                self.streamConfig.supportedVideoFormats |= VIDEO_FORMAT_AV1_MAIN8;
            }
#endif
            // Fall-through
            
        case CODEC_PREF_AUTO:
        case CODEC_PREF_HEVC:
            if (VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
                self.streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265;
            }
            // Fall-through
            
        case CODEC_PREF_H264:
            self.streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H264;
            break;
    }
    
    // HEVC is supported if the user wants it (or it's required by the chosen resolution) and the SoC supports it
    if ((self.streamConfig.width > 4096 || self.streamConfig.height > 4096 || streamSettings.enableHdr) && VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
        self.streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265;
        
        // HEVC Main10 is supported if the user wants it and the display supports it
        if (streamSettings.enableHdr && (AVPlayer.availableHDRModes & AVPlayerHDRModeHDR10) != 0) {
            self.streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265_MAIN10;
        }
    }
    
#if defined(__IPHONE_16_0) || defined(__TVOS_16_0)
    // Add the AV1 Main10 format if AV1 and HDR are both enabled and supported
    if ((self.streamConfig.supportedVideoFormats & VIDEO_FORMAT_MASK_AV1) && streamSettings.enableHdr &&
        VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1) && (AVPlayer.availableHDRModes & AVPlayerHDRModeHDR10) != 0) {
        self.streamConfig.supportedVideoFormats |= VIDEO_FORMAT_AV1_MAIN10;
    }
#endif
}

- (void)launchStreamingViewController {
    // Create the streaming view controller directly since it doesn't have a storyboard identifier
    StreamFrameViewController *streamVC = [[StreamFrameViewController alloc] init];
    
    // Set the stream configuration
    streamVC.streamConfig = self.streamConfig;
    
    // Present the streaming view controller
    [self.navigationController pushViewController:streamVC animated:YES];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
#if TARGET_OS_TV
    return CGSizeMake(300, 400);
#else
    return CGSizeMake(150, 200);
#endif
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end 