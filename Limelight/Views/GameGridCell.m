//
//  GameGridCell.m
//  Moonlight
//
//  Created by GameSphere on 6/13/25.
//  Copyright © 2025 Moonlight Stream. All rights reserved.
//

#import "GameGridCell.h"
#import "TemporaryApp.h"
#import <QuartzCore/QuartzCore.h>
#import "GameShortcutsViewController.h"
#import "AppAssetManager.h"

@implementation GameGridCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
        [self setupConstraints];
        [self setupStyling];
    }
    return self;
}

- (void)setupViews {
    // Main container with rounded corners
    self.layer.cornerRadius = 12.0;
    self.layer.masksToBounds = NO;
    self.backgroundColor = [UIColor clearColor];
    
    // Glow effect view (behind everything)
    self.glowEffectView = [[UIView alloc] init];
    self.glowEffectView.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:0.0];
    self.glowEffectView.layer.cornerRadius = 12.0;
    self.glowEffectView.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:1.0].CGColor;
    self.glowEffectView.layer.shadowOffset = CGSizeZero;
    self.glowEffectView.layer.shadowRadius = 0.0;
    self.glowEffectView.layer.shadowOpacity = 0.0;
    [self.contentView addSubview:self.glowEffectView];
    
    // Game image view
    self.gameImageView = [[UIImageView alloc] init];
    self.gameImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.gameImageView.clipsToBounds = YES;
    self.gameImageView.layer.cornerRadius = 12.0;
    self.gameImageView.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
    [self.contentView addSubview:self.gameImageView];
    
    // Overlay view for gradient effect
    self.overlayView = [[UIView alloc] init];
    self.overlayView.layer.cornerRadius = 12.0;
    self.overlayView.clipsToBounds = YES;
    [self.contentView addSubview:self.overlayView];
    
    // Gradient layer for bottom fade effect
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8].CGColor
    ];
    self.gradientLayer.locations = @[@0.6, @1.0];
    [self.overlayView.layer addSublayer:self.gradientLayer];
    
    // Game title label
    self.gameTitleLabel = [[UILabel alloc] init];
    self.gameTitleLabel.textColor = [UIColor whiteColor];
    self.gameTitleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    self.gameTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.gameTitleLabel.numberOfLines = 2;
    self.gameTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:self.gameTitleLabel];
}

- (void)setupConstraints {
    self.glowEffectView.translatesAutoresizingMaskIntoConstraints = NO;
    self.gameImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.overlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.gameTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        // Glow effect view (slightly larger than image)
        [self.glowEffectView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:-2],
        [self.glowEffectView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:-2],
        [self.glowEffectView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:2],
        [self.glowEffectView.bottomAnchor constraintEqualToAnchor:self.gameTitleLabel.topAnchor constant:2],
        
        // Game image view
        [self.gameImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.gameImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.gameImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.gameImageView.bottomAnchor constraintEqualToAnchor:self.gameTitleLabel.topAnchor constant:-8],
        
        // Overlay view (same as image)
        [self.overlayView.topAnchor constraintEqualToAnchor:self.gameImageView.topAnchor],
        [self.overlayView.leadingAnchor constraintEqualToAnchor:self.gameImageView.leadingAnchor],
        [self.overlayView.trailingAnchor constraintEqualToAnchor:self.gameImageView.trailingAnchor],
        [self.overlayView.bottomAnchor constraintEqualToAnchor:self.gameImageView.bottomAnchor],
        
        // Title label
        [self.gameTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:4],
        [self.gameTitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-4],
        [self.gameTitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.gameTitleLabel.heightAnchor constraintEqualToConstant:36]
    ]];
}

- (void)setupStyling {
    // Add subtle border
    self.gameImageView.layer.borderWidth = 1.0;
    self.gameImageView.layer.borderColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:0.5].CGColor;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.gradientLayer.frame = self.overlayView.bounds;
}

- (void)configureWithGame:(TemporaryApp *)game {
    self.gameTitleLabel.text = game.name;
    
    // Load game thumbnail with proper caching
    [self loadThumbnailForGame:game];
}

- (void)loadThumbnailForGame:(TemporaryApp *)game {
    UIImage *thumbnail = nil;
    
    // First check memory cache (if available from parent view controller)
    GameShortcutsViewController *parentVC = nil;
    UIResponder *responder = self.superview.nextResponder;
    while (responder && ![responder isKindOfClass:[GameShortcutsViewController class]]) {
        responder = responder.nextResponder;
    }
    if ([responder isKindOfClass:[GameShortcutsViewController class]]) {
        parentVC = (GameShortcutsViewController *)responder;
        thumbnail = [parentVC.boxArtCache objectForKey:game];
    }
    
    // If not in memory cache, try to load from disk
    if (!thumbnail) {
        NSString *boxArtPath = [AppAssetManager boxArtPathForApp:game];
        thumbnail = [UIImage imageWithContentsOfFile:boxArtPath];
        
        // Add to memory cache if loaded successfully
        if (thumbnail && parentVC) {
            [parentVC.boxArtCache setObject:thumbnail forKey:game];
        }
    }
    
    // Set the image or use placeholder
    if (thumbnail) {
        // Check if this is a blank/placeholder image from GameStream
        if (!(thumbnail.size.width == 130.f && thumbnail.size.height == 180.f) && // GFE 2.0
            !(thumbnail.size.width == 628.f && thumbnail.size.height == 888.f)) { // GFE 3.0
            self.gameImageView.image = thumbnail;
        } else {
            // Use placeholder for blank images
            self.gameImageView.image = [UIImage imageNamed:@"NoAppImage"];
        }
    } else {
        // Use placeholder when no image is available
        self.gameImageView.image = [UIImage imageNamed:@"NoAppImage"];
    }
}

- (void)configureWithROM:(NSDictionary *)romData {
    self.gameTitleLabel.text = romData[@"name"] ?: @"Unknown Game";
    
    // Set placeholder image initially
    self.gameImageView.image = [UIImage imageNamed:@"NoAppImage"];
    
    // Load ROM artwork from IGDB if available
    [self loadIGDBImageForROM:romData];
}

- (void)loadIGDBImageForROM:(NSDictionary *)romData {
    // Check if we already have a cover URL from IGDB
    NSString *coverURL = romData[@"cover_url"];
    if (coverURL && coverURL.length > 0) {
        // Load image from URL
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:coverURL]];
            if (imageData) {
                UIImage *coverImage = [UIImage imageWithData:imageData];
                if (coverImage) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // Only update if this cell is still showing the same ROM
                        if ([self.gameTitleLabel.text isEqualToString:romData[@"name"]]) {
                            self.gameImageView.image = coverImage;
                        }
                    });
                }
            }
        });
    }
}

- (void)setFocused:(BOOL)focused animated:(BOOL)animated {
    CGFloat duration = animated ? 0.3 : 0.0;
    
    if (focused) {
        // Scale up and add glow effect
        [UIView animateWithDuration:duration
                              delay:0.0
             usingSpringWithDamping:0.7
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            self.transform = CGAffineTransformMakeScale(1.1, 1.1);
            self.glowEffectView.layer.shadowOpacity = 0.8;
            self.glowEffectView.layer.shadowRadius = 20.0;
            self.glowEffectView.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:0.1];
            
            // Enhance the gradient overlay
            self.gradientLayer.colors = @[
                (id)[UIColor clearColor].CGColor,
                (id)[UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:0.3].CGColor
            ];
        } completion:nil];
        
        // Add subtle pulsing animation
        CABasicAnimation *pulseAnimation = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
        pulseAnimation.fromValue = @0.8;
        pulseAnimation.toValue = @0.4;
        pulseAnimation.duration = 1.0;
        pulseAnimation.autoreverses = YES;
        pulseAnimation.repeatCount = HUGE_VALF;
        [self.glowEffectView.layer addAnimation:pulseAnimation forKey:@"pulse"];
        
    } else {
        // Scale back to normal and remove glow
        [UIView animateWithDuration:duration
                              delay:0.0
             usingSpringWithDamping:0.7
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            self.transform = CGAffineTransformIdentity;
            self.glowEffectView.layer.shadowOpacity = 0.0;
            self.glowEffectView.layer.shadowRadius = 0.0;
            self.glowEffectView.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:0.0];
            
            // Reset gradient overlay
            self.gradientLayer.colors = @[
                (id)[UIColor clearColor].CGColor,
                (id)[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8].CGColor
            ];
        } completion:nil];
        
        // Remove pulsing animation
        [self.glowEffectView.layer removeAnimationForKey:@"pulse"];
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.gameImageView.image = nil;
    self.gameTitleLabel.text = nil;
    [self setFocused:NO animated:NO];
    [self.glowEffectView.layer removeAllAnimations];
}

@end 