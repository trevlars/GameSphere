//
//  GameListManager.m
//  Moonlight
//
//  Created by GameSphere on 6/13/25.
//  Copyright © 2025 Moonlight Stream. All rights reserved.
//

#import "GameListManager.h"
#import "TemporaryApp.h"
#import "TemporaryHost.h"

@implementation GameListManager

+ (instancetype)sharedManager {
    static GameListManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[GameListManager alloc] init];
    });
    return sharedInstance;
}

- (void)updateGamesFromHost:(TemporaryHost*)host {
    if (host && host.appList) {
        // Convert NSSet to NSArray and sort by name
        NSArray *appArray = [host.appList allObjects];
        self.games = [appArray sortedArrayUsingSelector:@selector(compareName:)];
        self.selectedHost = host;
        
        // Post notification that games have been updated
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GamesListUpdated" object:self.games];
    }
}

@end 