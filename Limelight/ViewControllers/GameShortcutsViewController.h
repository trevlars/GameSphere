//
//  GameShortcutsViewController.h
//  Moonlight
//
//  Created by GameSphere on 6/13/25.
//  Copyright © 2025 Moonlight Stream. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppAssetManager.h"
#import "DiscoveryManager.h"

@interface GameShortcutsViewController : UIViewController <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, AppAssetCallback, DiscoveryCallback>

@property (nonatomic, strong) UICollectionView *gameCollectionView;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) NSMutableArray *allGames; // Combined Moonlight + ROM games
@property (nonatomic, strong) NSString *igdbAccessToken;
@property (nonatomic, strong) AppAssetManager *appAssetManager;
@property (nonatomic, strong) NSCache *boxArtCache;

- (void)showSettings;

@end 