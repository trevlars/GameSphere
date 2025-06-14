//
//  GameGridCell.h
//  Moonlight
//
//  Created by GameSphere on 6/13/25.
//  Copyright © 2025 Moonlight Stream. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TemporaryApp;

@interface GameGridCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *gameImageView;
@property (nonatomic, strong) UILabel *gameTitleLabel;
@property (nonatomic, strong) UIView *glowEffectView;
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;

- (void)configureWithGame:(TemporaryApp *)game;
- (void)configureWithROM:(NSDictionary *)romData;
- (void)setFocused:(BOOL)focused animated:(BOOL)animated;

@end 