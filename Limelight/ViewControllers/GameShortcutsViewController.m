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

@interface GameShortcutsViewController () <AppCallback>
@property (nonatomic, strong) NSArray<TemporaryApp *> *games;
@property (nonatomic, strong) NSCache *boxArtCache;
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
    
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithTitle:@"Moonlight" 
                                                                       style:UIBarButtonItemStylePlain 
                                                                      target:self 
                                                                      action:@selector(showOriginalMoonlight)];
    
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

- (void)showOriginalMoonlight {
    // Load the original Moonlight storyboard and present it
    UIStoryboard *storyboard;
#if TARGET_OS_TV
    storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
#else
    storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
#endif
    
    UIViewController *originalVC = [storyboard instantiateInitialViewController];
    originalVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:originalVC animated:YES completion:nil];
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
    // Post notification to launch the game
    NSDictionary *userInfo = @{@"app": app, @"host": [GameListManager sharedManager].selectedHost};
    [[NSNotificationCenter defaultCenter] postNotificationName:@"LaunchGameFromShortcut" object:nil userInfo:userInfo];
}

- (void)appLongClicked:(TemporaryApp *)app view:(UIView *)view {
    // For now, just treat long clicks as regular clicks
    [self appClicked:app view:view];
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