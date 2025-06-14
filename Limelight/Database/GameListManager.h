//
//  GameListManager.h
//  Moonlight
//
//  Created by GameSphere on 6/13/25.
//  Copyright © 2025 Moonlight Stream. All rights reserved.
//

#import <Foundation/Foundation.h>
@class TemporaryApp;
@class TemporaryHost;

@interface GameListManager : NSObject

@property (nonatomic, strong) NSArray<TemporaryApp *> *games;
@property (nonatomic, strong) TemporaryHost *selectedHost;

+ (instancetype)sharedManager;
- (void)updateGamesFromHost:(TemporaryHost*)host;

@end 