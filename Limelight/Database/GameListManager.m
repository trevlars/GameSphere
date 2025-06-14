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
        // Load saved games on initialization
        [sharedInstance loadSavedGames];
    });
    return sharedInstance;
}

- (void)updateGamesFromHost:(TemporaryHost*)host {
    if (host && host.appList) {
        // Convert NSSet to NSArray and sort by name
        NSArray *appArray = [host.appList allObjects];
        self.games = [appArray sortedArrayUsingSelector:@selector(compareName:)];
        self.selectedHost = host;
        
        // Save the games data for persistence
        [self saveGamesData];
        
        // Post notification that games have been updated
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GamesListUpdated" object:self.games];
    }
}

- (void)saveGamesData {
    if (self.games.count == 0 || !self.selectedHost) {
        return;
    }
    
    NSMutableArray *gameDataArray = [[NSMutableArray alloc] init];
    
    // Serialize each game to a dictionary
    for (TemporaryApp *app in self.games) {
        NSDictionary *gameData = @{
            @"id": app.id ?: @"",
            @"name": app.name ?: @"",
            @"hidden": @(app.hidden),
            @"hostUUID": app.host.uuid ?: @"",
            @"hostName": app.host.name ?: @"",
            @"hostAddress": app.host.activeAddress ?: @"",
            @"hostLocalAddress": app.host.localAddress ?: @"",
            @"hostExternalAddress": app.host.externalAddress ?: @"",
            @"hostHttpsPort": @(app.host.httpsPort),
            @"hostServerCert": app.host.serverCert ?: [NSData data],
            @"hostServerCodecModeSupport": @(app.host.serverCodecModeSupport)
        };
        [gameDataArray addObject:gameData];
    }
    
    // Save the host information separately
    NSDictionary *hostData = @{
        @"uuid": self.selectedHost.uuid ?: @"",
        @"name": self.selectedHost.name ?: @"",
        @"activeAddress": self.selectedHost.activeAddress ?: @"",
        @"localAddress": self.selectedHost.localAddress ?: @"",
        @"externalAddress": self.selectedHost.externalAddress ?: @"",
        @"httpsPort": @(self.selectedHost.httpsPort),
        @"serverCert": self.selectedHost.serverCert ?: [NSData data],
        @"serverCodecModeSupport": @(self.selectedHost.serverCodecModeSupport)
    };
    
    NSDictionary *savedData = @{
        @"games": gameDataArray,
        @"selectedHost": hostData,
        @"savedTimestamp": [NSDate date]
    };
    
    // Save using the same pattern as other persistent data in the app
#if TARGET_OS_TV
    [[NSUserDefaults standardUserDefaults] setObject:savedData forKey:@"SavedGameShortcuts"];
    [[NSUserDefaults standardUserDefaults] synchronize];
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"SavedGameShortcuts.plist"];
    [savedData writeToFile:filePath atomically:YES];
#endif
    
    NSLog(@"Saved %lu game shortcuts to persistent storage", (unsigned long)self.games.count);
}

- (void)loadSavedGames {
    NSDictionary *savedData = nil;
    
    // Load using the same pattern as other persistent data in the app
#if TARGET_OS_TV
    savedData = [[NSUserDefaults standardUserDefaults] objectForKey:@"SavedGameShortcuts"];
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"SavedGameShortcuts.plist"];
    savedData = [NSDictionary dictionaryWithContentsOfFile:filePath];
#endif
    
    if (!savedData) {
        NSLog(@"No saved game shortcuts found");
        self.games = @[];
        return;
    }
    
    NSLog(@"Loading saved game shortcuts from persistent storage");
    
    // Restore the host first
    NSDictionary *hostData = savedData[@"selectedHost"];
    if (hostData) {
        TemporaryHost *host = [[TemporaryHost alloc] init];
        host.uuid = hostData[@"uuid"];
        host.name = hostData[@"name"];
        host.activeAddress = hostData[@"activeAddress"];
        host.localAddress = hostData[@"localAddress"];
        host.externalAddress = hostData[@"externalAddress"];
        host.httpsPort = [hostData[@"httpsPort"] intValue];
        host.serverCert = hostData[@"serverCert"];
        host.serverCodecModeSupport = [hostData[@"serverCodecModeSupport"] intValue];
        
        self.selectedHost = host;
    }
    
    // Restore the games
    NSArray *gameDataArray = savedData[@"games"];
    NSMutableArray *restoredGames = [[NSMutableArray alloc] init];
    
    for (NSDictionary *gameData in gameDataArray) {
        TemporaryApp *app = [[TemporaryApp alloc] init];
        app.id = gameData[@"id"];
        app.name = gameData[@"name"];
        app.hidden = [gameData[@"hidden"] boolValue];
        
        // Create a host object for this app (they should all be the same host)
        TemporaryHost *appHost = [[TemporaryHost alloc] init];
        appHost.uuid = gameData[@"hostUUID"];
        appHost.name = gameData[@"hostName"];
        appHost.activeAddress = gameData[@"hostAddress"];
        appHost.localAddress = gameData[@"hostLocalAddress"];
        appHost.externalAddress = gameData[@"hostExternalAddress"];
        appHost.httpsPort = [gameData[@"hostHttpsPort"] intValue];
        appHost.serverCert = gameData[@"hostServerCert"];
        appHost.serverCodecModeSupport = [gameData[@"hostServerCodecModeSupport"] intValue];
        
        app.host = appHost;
        [restoredGames addObject:app];
    }
    
    self.games = [restoredGames copy];
    
    NSLog(@"Loaded %lu game shortcuts from persistent storage", (unsigned long)self.games.count);
    
    // Post notification that games have been loaded
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GamesListUpdated" object:self.games];
}

- (void)clearSavedGames {
    NSLog(@"Clearing saved game shortcuts");
    
    self.games = @[];
    self.selectedHost = nil;
    
    // Remove from persistent storage
#if TARGET_OS_TV
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SavedGameShortcuts"];
    [[NSUserDefaults standardUserDefaults] synchronize];
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"SavedGameShortcuts.plist"];
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
#endif
    
    // Post notification that games have been cleared
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GamesListUpdated" object:self.games];
}

@end 