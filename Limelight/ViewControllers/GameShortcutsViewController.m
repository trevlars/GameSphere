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
#import "GameGridCell.h"
#import "IGDBManager.h"
#import "GameSphereSettingsViewController.h"
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
#import "Log.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <sys/utsname.h>

static NSString * const kGameCellIdentifier = @"GameGridCell";

@interface GameShortcutsViewController ()

@property (nonatomic, strong) UIView *backgroundGradientView;
@property (nonatomic, strong) CAGradientLayer *backgroundGradient;
@property (nonatomic, strong) UIVisualEffectView *blurEffectView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) NSIndexPath *focusedIndexPath;

// Discovery and networking
@property (nonatomic, strong) DiscoveryManager *discMan;
@property (nonatomic, strong) NSString *uniqueId;
@property (nonatomic, strong) NSData *clientCert;
@property (nonatomic, strong) StreamConfiguration *streamConfig;

// Operation queue for background tasks
@property (nonatomic, strong) NSOperationQueue *opQueue;

// Host management
@property (nonatomic, strong) NSMutableSet *hostList;
@property (nonatomic, strong) TemporaryHost *selectedHost;
@property (nonatomic) BOOL background;

// Automatic refresh timer
@property (nonatomic, strong) NSTimer *autoRefreshTimer;

@end

@implementation GameShortcutsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize properties
    self.allGames = [[NSMutableArray alloc] init];
    self.opQueue = [[NSOperationQueue alloc] init];
    self.uniqueId = [IdManager getUniqueId];
    self.clientCert = [CryptoManager readCertFromFile];
    
    // Initialize thumbnail management
    self.boxArtCache = [[NSCache alloc] init];
    self.appAssetManager = [[AppAssetManager alloc] initWithCallback:self];
    
    // Load cached games FIRST so the view isn't empty
    [self loadCachedGames];
    
    // Initialize discovery system and start it immediately
    [self initializeDiscoverySystem];
    [self startDiscoveryImmediately];
    
    [self setupBackground];
    [self setupNavigationBar];
    [self setupHeaderView];
    [self setupCollectionView];
    [self setupDescriptionLabel];
    [self setupConstraints];
    [self setupNotifications];
    
    // Authenticate with IGDB
    [[IGDBManager sharedManager] authenticateWithClientId:@"7aj0d5y3mglfxu2ni7mpvy5jg26rkb" 
                                             clientSecret:@"g84eqdzwpz864ul5l5aolansgiaaea" 
                                               completion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"IGDB authentication successful");
        } else {
            NSLog(@"IGDB authentication failed: %@", error.localizedDescription);
        }
    }];
}

- (void)loadCachedGames {
    // Load games from persistent storage immediately so view isn't empty
    GameListManager *gameManager = [GameListManager sharedManager];
    [gameManager loadSavedGames];
    
    // Clear existing games first
    [self.allGames removeAllObjects];
    
    if (gameManager.games && gameManager.games.count > 0) {
        [self.allGames addObjectsFromArray:gameManager.games];
        Log(LOG_I, @"GameShortcuts: Loaded %lu cached games from storage", (unsigned long)gameManager.games.count);
    } else {
        Log(LOG_I, @"GameShortcuts: No cached games found in storage");
    }
    
    // Add placeholder ROM games for demo purposes
    NSArray *roms = [self loadPlaceholderROMs];
    [self.allGames addObjectsFromArray:roms];
    
    // Update UI immediately with cached games and ROMs
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.gameCollectionView reloadData];
    });
    
    // Load IGDB metadata for ROM games after a short delay to allow authentication
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self loadIGDBMetadataForROMs];
    });
}

- (void)startDiscoveryImmediately {
    // Start discovery right away, don't wait for viewWillAppear
    Log(LOG_I, @"GameShortcuts: Starting automatic discovery on app launch");
    [self.discMan startDiscovery];
    
    // Set up automatic refresh timer for continuous discovery
    [self setupAutomaticRefresh];
}

- (void)setupAutomaticRefresh {
    // Set up a timer to automatically refresh discovery every 30 seconds
    // This ensures we always have the latest games without manual intervention
    self.autoRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                             target:self
                                                           selector:@selector(performAutomaticRefresh)
                                                           userInfo:nil
                                                            repeats:YES];
    Log(LOG_I, @"GameShortcuts: Automatic refresh timer started (30s intervals)");
}

- (void)performAutomaticRefresh {
    if (!self.background) {
        Log(LOG_D, @"GameShortcuts: Performing automatic discovery refresh");
        [self.discMan startDiscovery];
    }
}

- (void)initializeDiscoverySystem {
    // Set up crypto
    [CryptoManager generateKeyPairUsingSSL];
    
    // Initialize host list
    if (self.hostList == nil) {
        self.hostList = [[NSMutableSet alloc] init];
    }
    
    // Retrieve saved hosts
    [self retrieveSavedHosts];
    
    // Initialize discovery manager
    self.discMan = [[DiscoveryManager alloc] initWithHosts:[self.hostList allObjects] andCallback:self];
}

- (void)retrieveSavedHosts {
    DataManager* dataMan = [[DataManager alloc] init];
    NSArray* hosts = [dataMan getHosts];
    @synchronized(self.hostList) {
        [self.hostList addObjectsFromArray:hosts];
        
        // Initialize the non-persistent host state
        for (TemporaryHost* host in self.hostList) {
            host.pairState = PairStateUnknown;
            host.state = StateUnknown;
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    
    // Discovery is already running automatically, just ensure we're not in background mode
    self.background = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Set up background/foreground notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleReturnToForeground)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleEnterBackground)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    // Stop discovery when view disappears
    [self.discMan stopDiscovery];
    
    // Remove observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)beginForegroundRefresh {
    if (!self.background) {
        // Reset discovery state and start discovery
        [self.discMan resetDiscoveryState];
        [self.discMan startDiscovery];
    }
}

- (void)handleReturnToForeground {
    self.background = NO;
    [self beginForegroundRefresh];
}

- (void)handleEnterBackground {
    self.background = YES;
    [self.discMan stopDiscovery];
}

- (void)setupBackground {
    // Create futuristic gradient background
    self.backgroundGradientView = [[UIView alloc] init];
    [self.view addSubview:self.backgroundGradientView];
    
    self.backgroundGradient = [CAGradientLayer layer];
    self.backgroundGradient.colors = @[
        (id)[UIColor colorWithRed:0.05 green:0.05 blue:0.15 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.1 green:0.1 blue:0.2 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.05 green:0.05 blue:0.1 alpha:1.0].CGColor
    ];
    self.backgroundGradient.locations = @[@0.0, @0.5, @1.0];
    self.backgroundGradient.startPoint = CGPointMake(0.0, 0.0);
    self.backgroundGradient.endPoint = CGPointMake(1.0, 1.0);
    [self.backgroundGradientView.layer addSublayer:self.backgroundGradient];
    
    // Add subtle animated particles effect (optional)
    [self addParticleEffect];
}

- (void)addParticleEffect {
    // Create subtle floating particles for futuristic feel
    for (int i = 0; i < 20; i++) {
        UIView *particle = [[UIView alloc] init];
        particle.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:0.1];
        particle.layer.cornerRadius = 1.0;
        [self.backgroundGradientView addSubview:particle];
        
        // Random position and size
        CGFloat size = 2.0 + (arc4random_uniform(3));
        particle.frame = CGRectMake(arc4random_uniform(400), arc4random_uniform(800), size, size);
        
        // Animate floating motion
        [UIView animateWithDuration:10.0 + arc4random_uniform(10)
                              delay:arc4random_uniform(5)
                            options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            particle.transform = CGAffineTransformMakeTranslation(
                -50 + arc4random_uniform(100),
                -50 + arc4random_uniform(100)
            );
            particle.alpha = 0.05 + (arc4random_uniform(10) / 100.0);
        } completion:nil];
    }
}

- (void)setupNavigationBar {
    // Don't set title since we have a custom header view
    self.title = @"";
    
    // Style navigation bar
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.2 alpha:0.95];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:1.0];
    self.navigationController.navigationBar.titleTextAttributes = @{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [UIFont systemFontOfSize:20.0 weight:UIFontWeightBold]
    };
    
    // Only add settings button - refresh is now automatic
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithTitle:@"Settings"
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(showSettings)];
    
    self.navigationItem.rightBarButtonItem = settingsButton;
}

- (void)setupHeaderView {
    // Create header view
    self.headerView = [[UIView alloc] init];
    self.headerView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.headerView];
    
    // Title label
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"GameSphere";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.headerView addSubview:self.titleLabel];
    
    // Subtitle label
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.text = @"Select a game to see its description";
    self.subtitleLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.subtitleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.headerView addSubview:self.subtitleLabel];
}

- (void)setupCollectionView {
    // Create collection view layout
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumInteritemSpacing = 20.0;
    layout.minimumLineSpacing = 30.0;
    layout.sectionInset = UIEdgeInsetsMake(20, 20, 20, 20);
    
    // Calculate item size based on screen width
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat itemsPerRow = (screenWidth > 1000) ? 6 : 4; // More items on larger screens
    CGFloat itemWidth = (screenWidth - (layout.sectionInset.left + layout.sectionInset.right) - (layout.minimumInteritemSpacing * (itemsPerRow - 1))) / itemsPerRow;
    CGFloat itemHeight = itemWidth * 1.4 + 40; // Aspect ratio + space for title
    
    layout.itemSize = CGSizeMake(itemWidth, itemHeight);
    
    // Create collection view
    self.gameCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.gameCollectionView.backgroundColor = [UIColor clearColor];
    self.gameCollectionView.delegate = self;
    self.gameCollectionView.dataSource = self;
    self.gameCollectionView.showsVerticalScrollIndicator = NO;
    self.gameCollectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    
    // Register cell
    [self.gameCollectionView registerClass:[GameGridCell class] forCellWithReuseIdentifier:kGameCellIdentifier];
    
    [self.view addSubview:self.gameCollectionView];
}

- (void)setupDescriptionLabel {
    // Create description label
    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.textColor = [UIColor whiteColor];
    self.descriptionLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    self.descriptionLabel.numberOfLines = 0;
    self.descriptionLabel.textAlignment = NSTextAlignmentCenter;
    self.descriptionLabel.text = @"Select a game to see its description";
    [self.view addSubview:self.descriptionLabel];
}

- (void)setupConstraints {
    self.backgroundGradientView.translatesAutoresizingMaskIntoConstraints = NO;
    self.gameCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        // Background gradient
        [self.backgroundGradientView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backgroundGradientView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backgroundGradientView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backgroundGradientView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        // Collection view
        [self.gameCollectionView.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:20],
        [self.gameCollectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.gameCollectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.gameCollectionView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        
        // Header view
        [self.headerView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.headerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.headerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.headerView.bottomAnchor constraintEqualToAnchor:self.gameCollectionView.topAnchor constant:-20],
        
        // Title label
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.headerView.topAnchor constant:15],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:20],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-20],
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:-15],
        
        // Subtitle label
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:5],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:-15]
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.backgroundGradient.frame = self.backgroundGradientView.bounds;
}

- (void)loadGames {
    // This method is called by notifications - just reload from hosts or cache
    if (self.hostList && [self.hostList count] > 0) {
        [self loadGamesFromHosts];
    } else {
        // Fallback: load saved games from persistent storage
        [self loadSavedGames];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.gameCollectionView reloadData];
        });
    }
}

- (void)loadSavedGames {
    // Load games from persistent storage as fallback
    GameListManager *gameManager = [GameListManager sharedManager];
    [gameManager loadSavedGames];
    
    // Clear existing games first
    [self.allGames removeAllObjects];
    
    if (gameManager.games && gameManager.games.count > 0) {
        [self.allGames addObjectsFromArray:gameManager.games];
        Log(LOG_I, @"GameShortcuts: Loaded %lu saved games from storage", (unsigned long)gameManager.games.count);
    } else {
        Log(LOG_I, @"GameShortcuts: No saved games found in storage");
    }
    
    // Always add ROMs to the list
    NSArray *roms = [self loadPlaceholderROMs];
    [self.allGames addObjectsFromArray:roms];
}

- (NSArray *)loadPlaceholderROMs {
    // Add some placeholder ROM data
    NSArray *placeholderROMs = @[
        @{@"name": @"Super Mario Bros.", @"type": @"ROM", @"system": @"NES"},
        @{@"name": @"The Legend of Zelda", @"type": @"ROM", @"system": @"NES"},
        @{@"name": @"Sonic the Hedgehog", @"type": @"ROM", @"system": @"Genesis"},
        @{@"name": @"Street Fighter II", @"type": @"ROM", @"system": @"SNES"},
        @{@"name": @"Final Fantasy VII", @"type": @"ROM", @"system": @"PSX"}
    ];
    
    return placeholderROMs;
}

- (void)authenticateWithIGDB {
    IGDBManager *igdbManager = [IGDBManager sharedManager];
    [igdbManager authenticateWithClientId:@"7aj0d5y3mglfxu2ni7mpvy5jg26rkb"
                             clientSecret:@"g84eqdzwpz864ul5l5aolansgiaaea"
                               completion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"IGDB authentication successful");
            // Start loading metadata for ROMs
            [self loadIGDBMetadataForROMs];
        } else {
            NSLog(@"IGDB authentication failed: %@", error.localizedDescription);
        }
    }];
}

- (void)loadIGDBMetadataForROMs {
    // Load IGDB metadata for ROM games
    for (NSInteger i = 0; i < self.allGames.count; i++) {
        id game = self.allGames[i];
        if ([game isKindOfClass:[NSDictionary class]] && [game[@"type"] isEqualToString:@"ROM"]) {
            NSString *gameName = game[@"name"];
            [self loadIGDBDataForGame:gameName atIndex:i];
        }
    }
}

- (void)loadIGDBDataForGame:(NSString *)gameName atIndex:(NSInteger)index {
    IGDBManager *igdbManager = [IGDBManager sharedManager];
    [igdbManager searchGameWithName:gameName completion:^(NSDictionary *gameData, NSError *error) {
        if (gameData && !error) {
            // Update the game data with IGDB info
            NSMutableDictionary *updatedGame = [self.allGames[index] mutableCopy];
            updatedGame[@"igdb_data"] = gameData;
            updatedGame[@"summary"] = gameData[@"summary"] ?: @"No description available";
            
            // Get cover art if available
            NSDictionary *cover = gameData[@"cover"];
            if (cover && cover[@"image_id"]) {
                NSString *imageURL = [igdbManager constructImageURL:cover[@"image_id"] size:@"cover_big"];
                updatedGame[@"cover_url"] = imageURL;
                NSLog(@"IGDB: Found cover art for %@: %@", gameName, imageURL);
            }
            
            // Replace the game in the array
            [self.allGames replaceObjectAtIndex:index withObject:updatedGame];
            
            // Reload the specific cell
            dispatch_async(dispatch_get_main_queue(), ^{
                if (index < self.allGames.count) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
                    [self.gameCollectionView reloadItemsAtIndexPaths:@[indexPath]];
                }
            });
        } else {
            NSLog(@"IGDB: Failed to load data for %@: %@", gameName, error.localizedDescription);
        }
    }];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.allGames.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    GameGridCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kGameCellIdentifier forIndexPath:indexPath];
    
    id game = self.allGames[indexPath.item];
    
    if ([game isKindOfClass:[TemporaryApp class]]) {
        [cell configureWithGame:(TemporaryApp *)game];
    } else if ([game isKindOfClass:[NSDictionary class]]) {
        [cell configureWithROM:(NSDictionary *)game];
    }
    
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    id game = self.allGames[indexPath.item];
    
    if ([game isKindOfClass:[TemporaryApp class]]) {
        // Launch Moonlight game
        [self launchMoonlightGame:(TemporaryApp *)game];
    } else if ([game isKindOfClass:[NSDictionary class]]) {
        // Launch ROM game (placeholder for now)
        [self launchROMGame:(NSDictionary *)game];
    }
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    // Only update focus on highlight for non-tvOS platforms
#if !TARGET_OS_TV
    [self updateFocusForIndexPath:indexPath];
#endif
}

#if TARGET_OS_TV
// MARK: - tvOS Focus Engine Support

- (BOOL)collectionView:(UICollectionView *)collectionView canFocusItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didUpdateFocusInContext:(UICollectionViewFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    // Handle focus changes on tvOS
    if (context.nextFocusedIndexPath) {
        [coordinator addCoordinatedAnimations:^{
            [self updateFocusForIndexPath:context.nextFocusedIndexPath];
        } completion:nil];
    }
    
    // Remove focus from previous cell
    if (context.previouslyFocusedIndexPath) {
        GameGridCell *previousCell = (GameGridCell *)[collectionView cellForItemAtIndexPath:context.previouslyFocusedIndexPath];
        [coordinator addCoordinatedAnimations:^{
            [previousCell setFocused:NO animated:YES];
        } completion:nil];
    }
}
#endif

- (void)updateFocusForIndexPath:(NSIndexPath *)indexPath {
    // Remove focus from previous cell
    if (self.focusedIndexPath) {
        GameGridCell *previousCell = (GameGridCell *)[self.gameCollectionView cellForItemAtIndexPath:self.focusedIndexPath];
        [previousCell setFocused:NO animated:YES];
    }
    
    // Add focus to new cell
    GameGridCell *currentCell = (GameGridCell *)[self.gameCollectionView cellForItemAtIndexPath:indexPath];
    [currentCell setFocused:YES animated:YES];
    
    self.focusedIndexPath = indexPath;
    
    // Update description
    [self updateDescriptionForGame:self.allGames[indexPath.item]];
}

- (void)updateDescriptionForGame:(id)game {
    NSString *description = @"Select a game to see its description";
    
    if ([game isKindOfClass:[TemporaryApp class]]) {
        TemporaryApp *app = (TemporaryApp *)game;
        description = [NSString stringWithFormat:@"🎮 %@\nMoonlight Game - Ready to stream from your gaming PC", app.name];
    } else if ([game isKindOfClass:[NSDictionary class]]) {
        NSDictionary *romGame = (NSDictionary *)game;
        NSString *summary = romGame[@"summary"];
        if (summary && summary.length > 0) {
            description = [NSString stringWithFormat:@"🕹️ %@\n%@", romGame[@"name"], summary];
        } else {
            description = [NSString stringWithFormat:@"🕹️ %@\n%@ ROM - Classic gaming experience", romGame[@"name"], romGame[@"system"]];
        }
    }
    
    // Animate description update
    [UIView animateWithDuration:0.3 animations:^{
        self.subtitleLabel.text = description;
    }];
}

#pragma mark - Game Launch Methods

- (void)launchMoonlightGame:(TemporaryApp *)game {
    if (!game || !game.host) {
        Log(LOG_E, @"Cannot launch game: missing app or host information");
        return;
    }
    
    // Check if host is paired
    if (game.host.pairState != PairStatePaired) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Device Not Paired"
                                                                       message:@"This device is not paired with the gaming PC. Please use the Moonlight settings to pair with your PC first."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Create stream configuration with all required properties
    DataManager *dataMan = [[DataManager alloc] init];
    TemporarySettings *settings = [dataMan getSettings];
    
    StreamConfiguration *streamConfig = [[StreamConfiguration alloc] init];
    streamConfig.host = game.host.activeAddress; // Use activeAddress - the verified working address
    streamConfig.httpsPort = game.host.httpsPort; // CRITICAL: HTTPS port for secure communication
    streamConfig.appID = game.id;
    streamConfig.appName = game.name;
    streamConfig.serverCert = game.host.serverCert; // CRITICAL: Server certificate for authentication
    
    // Apply settings with correct type conversions
    streamConfig.frameRate = [settings.framerate intValue];
    if (@available(iOS 10.3, *)) {
        // Don't stream more FPS than the display can show
        if (streamConfig.frameRate > [UIScreen mainScreen].maximumFramesPerSecond) {
            streamConfig.frameRate = (int)[UIScreen mainScreen].maximumFramesPerSecond;
            Log(LOG_W, @"Clamping FPS to maximum refresh rate: %d", streamConfig.frameRate);
        }
    }
    
    streamConfig.height = [settings.height intValue];
    streamConfig.width = [settings.width intValue];
    
#if TARGET_OS_TV
    // Don't allow streaming 4K on the Apple TV HD
    struct utsname systemInfo;
    uname(&systemInfo);
    if (strcmp(systemInfo.machine, "AppleTV5,3") == 0 && streamConfig.height >= 2160) {
        Log(LOG_W, @"4K streaming not supported on Apple TV HD");
        streamConfig.width = 1920;
        streamConfig.height = 1080;
    }
#endif
    
    streamConfig.bitRate = [settings.bitrate intValue];
    streamConfig.optimizeGameSettings = settings.optimizeGames;
    streamConfig.playAudioOnPC = settings.playAudioOnPC;
    streamConfig.useFramePacing = settings.useFramePacing;
    streamConfig.swapABXYButtons = settings.swapABXYButtons;
    
    // multiController must be set before calling getConnectedGamepadMask
    streamConfig.multiController = settings.multiController;
    streamConfig.gamepadMask = [ControllerSupport getConnectedGamepadMask:streamConfig];
    
    // Probe for supported channel configurations
    int physicalOutputChannels = (int)[AVAudioSession sharedInstance].maximumOutputNumberOfChannels;
    Log(LOG_I, @"Audio device supports %d channels", physicalOutputChannels);
    
    int numberOfChannels = MIN([settings.audioConfig intValue], physicalOutputChannels);
    Log(LOG_I, @"Selected number of audio channels %d", numberOfChannels);
    if (numberOfChannels >= 8) {
        streamConfig.audioConfiguration = AUDIO_CONFIGURATION_71_SURROUND;
    }
    else if (numberOfChannels >= 6) {
        streamConfig.audioConfiguration = AUDIO_CONFIGURATION_51_SURROUND;
    }
    else {
        streamConfig.audioConfiguration = AUDIO_CONFIGURATION_STEREO;
    }
    
    streamConfig.serverCodecModeSupport = game.host.serverCodecModeSupport;
    
    // Set up video codec support
    switch (settings.preferredCodec) {
        case CODEC_PREF_AV1:
#if defined(__IPHONE_16_0) || defined(__TVOS_16_0)
            if (VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)) {
                streamConfig.supportedVideoFormats |= VIDEO_FORMAT_AV1_MAIN8;
            }
#endif
            // Fall-through
            
        case CODEC_PREF_AUTO:
        case CODEC_PREF_HEVC:
            if (VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
                streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265;
            }
            // Fall-through
            
        case CODEC_PREF_H264:
            streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H264;
            break;
    }
    
    // HEVC is supported if the user wants it (or it's required by the chosen resolution) and the SoC supports it
    if ((streamConfig.width > 4096 || streamConfig.height > 4096 || settings.enableHdr) && VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
        streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265;
        
        // HEVC Main10 is supported if the user wants it and the display supports it
        if (settings.enableHdr && (AVPlayer.availableHDRModes & AVPlayerHDRModeHDR10) != 0) {
            streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265_MAIN10;
        }
    }
    
#if defined(__IPHONE_16_0) || defined(__TVOS_16_0)
    // Add the AV1 Main10 format if AV1 and HDR are both enabled and supported
    if ((streamConfig.supportedVideoFormats & VIDEO_FORMAT_MASK_AV1) && settings.enableHdr &&
        VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1) && (AVPlayer.availableHDRModes & AVPlayerHDRModeHDR10) != 0) {
        streamConfig.supportedVideoFormats |= VIDEO_FORMAT_AV1_MAIN10;
    }
#endif
    
    // Create and present stream view controller
    StreamFrameViewController *streamFrameVC = [[StreamFrameViewController alloc] init];
    streamFrameVC.streamConfig = streamConfig;
    
    [self presentViewController:streamFrameVC animated:YES completion:nil];
}

- (void)launchROMGame:(NSDictionary *)romGame {
    // Implement ROM game launch logic
    NSLog(@"Launching ROM game: %@", romGame[@"name"]);
    // You'll need to implement the actual ROM launch logic here
}

#pragma mark - Actions

// refreshGames method removed - discovery is now automatic

- (void)showSettings {
    GameSphereSettingsViewController *settingsVC = [[GameSphereSettingsViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    
    // Style the navigation bar to match the app theme
    navController.navigationBar.barTintColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
    navController.navigationBar.tintColor = [UIColor whiteColor];
    navController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    
    [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark - Notifications

- (void)handleGamesUpdated:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadGames];
    });
}

- (void)handleManualRefresh:(NSNotification *)notification {
    Log(LOG_I, @"GameShortcuts: Manual refresh requested from settings");
    
    // Force a fresh discovery scan
    [self.discMan stopDiscovery];
    [self.discMan resetDiscoveryState];
    [self.discMan startDiscovery];
}

- (void)dealloc {
    // Clean up timer
    [self.autoRefreshTimer invalidate];
    self.autoRefreshTimer = nil;
    
    // Stop discovery
    [self.discMan stopDiscovery];
    
    // Remove observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showOriginalMoonlight {
    // Create the original MainFrameViewController
    UIStoryboard *storyboard;
    
#if TARGET_OS_TV
    storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
#else
    storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
#endif
    
    MainFrameViewController *mainFrameVC = [storyboard instantiateViewControllerWithIdentifier:@"MainFrameViewController"];
    
    if (!mainFrameVC) {
        // Fallback: create manually if storyboard instantiation fails
        mainFrameVC = [[MainFrameViewController alloc] init];
    }
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:mainFrameVC];
    
    // Style the navigation bar to match Moonlight's theme
    navController.navigationBar.barTintColor = [UIColor colorWithRed:0.33 green:0.33 blue:0.33 alpha:1.0];
    navController.navigationBar.tintColor = [UIColor whiteColor];
    navController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    navController.navigationBar.translucent = NO;
    
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)launchGame:(TemporaryApp *)app {
    if (!app || !app.host) {
        Log(LOG_E, @"Cannot launch game: missing app or host information");
        return;
    }
    
    // Create stream configuration
    DataManager *dataMan = [[DataManager alloc] init];
    TemporarySettings *settings = [dataMan getSettings];
    
    StreamConfiguration *streamConfig = [[StreamConfiguration alloc] init];
    streamConfig.host = app.host.activeAddress; // Use activeAddress - the verified working address
    streamConfig.appID = app.id;
    streamConfig.appName = app.name;
    
    // Apply settings with correct type conversions
    streamConfig.frameRate = [settings.framerate intValue];
    streamConfig.bitRate = [settings.bitrate intValue];
    streamConfig.height = [settings.height intValue];
    streamConfig.width = [settings.width intValue];
    streamConfig.optimizeGameSettings = settings.optimizeGames;
    streamConfig.multiController = settings.multiController;
    streamConfig.playAudioOnPC = settings.playAudioOnPC;
    streamConfig.useFramePacing = settings.useFramePacing;
    streamConfig.swapABXYButtons = settings.swapABXYButtons;
    
    // Create and present stream view controller
    StreamFrameViewController *streamFrameVC = [[StreamFrameViewController alloc] init];
    streamFrameVC.streamConfig = streamConfig;
    
    [self presentViewController:streamFrameVC animated:YES completion:nil];
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleGamesUpdated:)
                                                 name:@"GamesUpdatedNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleManualRefresh:)
                                                 name:@"ManualRefreshGamesRequested"
                                               object:nil];
}

#pragma mark - AppAssetCallback

- (void)receivedAssetForApp:(TemporaryApp *)app {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Find the index of this app in our games array
        NSInteger index = [self.allGames indexOfObject:app];
        if (index != NSNotFound) {
            // Reload the specific cell to show the new thumbnail
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
            [self.gameCollectionView reloadItemsAtIndexPaths:@[indexPath]];
        }
    });
}

#pragma mark - DiscoveryCallback

- (void)updateAllHosts:(NSArray *)hosts {
    // We must copy the array here because it could be modified
    // before our main thread dispatch happens.
    NSArray* hostsCopy = [NSArray arrayWithArray:hosts];
    dispatch_async(dispatch_get_main_queue(), ^{
        Log(LOG_D, @"GameShortcuts: New host list received with %lu hosts", (unsigned long)[hostsCopy count]);
        
        @synchronized(self.hostList) {
            [self.hostList removeAllObjects];
            [self.hostList addObjectsFromArray:hostsCopy];
        }
        
        // Reload games from updated hosts
        [self loadGamesFromHosts];
    });
}

- (void)loadGamesFromHosts {
    // Create a new array for discovered games
    NSMutableArray *discoveredGames = [[NSMutableArray alloc] init];
    
    @synchronized(self.hostList) {
        for (TemporaryHost* host in self.hostList) {
            // Include games from ALL discovered hosts (regardless of pairing/online status)
            // This creates shortcuts for all games from all PC servers
            if (host.appList && [host.appList count] > 0) {
                Log(LOG_D, @"Loading games from host: %@ (apps: %lu, paired: %s, online: %s)", 
                    host.name, 
                    (unsigned long)[host.appList count],
                    (host.pairState == PairStatePaired) ? "YES" : "NO",
                    (host.state == StateOnline) ? "YES" : "NO");
                [discoveredGames addObjectsFromArray:[host.appList allObjects]];
                
                // Start downloading thumbnails for these games (even if not paired/online)
                [self.appAssetManager retrieveAssetsFromHost:host];
            }
        }
    }
    
    // Only update if we actually discovered games
    if (discoveredGames.count > 0) {
        // Replace games with fresh discovery results
        [self.allGames removeAllObjects];
        [self.allGames addObjectsFromArray:discoveredGames];
        
        // Add ROMs to the updated list
        NSArray *roms = [self loadPlaceholderROMs];
        [self.allGames addObjectsFromArray:roms];
        
        // Sort Moonlight games alphabetically (keep ROMs at the end)
        NSMutableArray *moonlightGames = [[NSMutableArray alloc] init];
        NSMutableArray *romGames = [[NSMutableArray alloc] init];
        
        for (id game in self.allGames) {
            if ([game isKindOfClass:[TemporaryApp class]]) {
                [moonlightGames addObject:game];
            } else {
                [romGames addObject:game];
            }
        }
        
        [moonlightGames sortUsingSelector:@selector(compareName:)];
        
        [self.allGames removeAllObjects];
        [self.allGames addObjectsFromArray:moonlightGames];
        [self.allGames addObjectsFromArray:romGames];
        
        // Save only the Moonlight games (not ROMs)
        GameListManager *gameManager = [GameListManager sharedManager];
        gameManager.games = [moonlightGames copy];
        [gameManager saveGamesData];
        
        // Reload the collection view
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.gameCollectionView reloadData];
        });
        
        Log(LOG_I, @"GameShortcuts: Updated with %lu Moonlight games from discovered hosts", (unsigned long)moonlightGames.count);
    } else {
        Log(LOG_D, @"GameShortcuts: No online paired hosts found, keeping cached games");
    }
}

@end 