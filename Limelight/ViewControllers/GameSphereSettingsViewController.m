//
//  GameSphereSettingsViewController.m
//  Moonlight
//
//  Created by GameSphere on 6/13/25.
//  Copyright © 2025 Moonlight Stream. All rights reserved.
//

#import "GameSphereSettingsViewController.h"
#import "GameListManager.h"

typedef NS_ENUM(NSInteger, SettingsSection) {
    SettingsSectionMoonlight = 0,
    SettingsSectionShortcuts,
    SettingsSectionEmulators,
    SettingsSectionCount
};

typedef NS_ENUM(NSInteger, MoonlightRow) {
    MoonlightRowOpen = 0,
    MoonlightRowCount
};

typedef NS_ENUM(NSInteger, ShortcutsRow) {
    ShortcutsRowRefresh = 0,
    ShortcutsRowClear,
    ShortcutsRowCount
};

typedef NS_ENUM(NSInteger, EmulatorsRow) {
    EmulatorsRowROMSettings = 0,
    EmulatorsRowCount
};

@implementation GameSphereSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Settings";
    self.view.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    
    // Add close button
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                 target:self
                                                                                 action:@selector(closeSettings)];
    self.navigationItem.rightBarButtonItem = closeButton;
    
    // Style the table view
    self.tableView.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
#if !TARGET_OS_TV
    // separatorColor is not available on tvOS
    self.tableView.separatorColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
#endif
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionMoonlight:
            return MoonlightRowCount;
        case SettingsSectionShortcuts:
            return ShortcutsRowCount;
        case SettingsSectionEmulators:
            return EmulatorsRowCount;
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionMoonlight:
            return @"Moonlight";
        case SettingsSectionShortcuts:
            return @"Game Shortcuts";
        case SettingsSectionEmulators:
            return @"Emulators";
        default:
            return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionMoonlight:
            return @"Access the original Moonlight interface to connect to your gaming PC and discover games.";
        case SettingsSectionShortcuts:
            return @"Manage your saved game shortcuts that appear on the main screen.";
        case SettingsSectionEmulators:
            return @"Configure emulator settings and ROM management (coming soon).";
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingsCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SettingsCell"];
        cell.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    switch (indexPath.section) {
        case SettingsSectionMoonlight:
            switch (indexPath.row) {
                case MoonlightRowOpen:
                    cell.textLabel.text = @"Open Moonlight";
                    if (@available(tvOS 13.0, iOS 13.0, *)) {
                        cell.imageView.image = [UIImage systemImageNamed:@"gamecontroller"];
                    } else {
                        cell.imageView.image = nil;
                    }
                    break;
            }
            break;
            
        case SettingsSectionShortcuts:
            switch (indexPath.row) {
                case ShortcutsRowRefresh:
                    cell.textLabel.text = @"Refresh Games";
                    cell.textLabel.textColor = [UIColor whiteColor];
                    if (@available(tvOS 13.0, iOS 13.0, *)) {
                        cell.imageView.image = [UIImage systemImageNamed:@"arrow.clockwise"];
                    } else {
                        cell.imageView.image = nil;
                    }
                    break;
                case ShortcutsRowClear:
                    cell.textLabel.text = @"Clear All Shortcuts";
                    cell.textLabel.textColor = [UIColor systemRedColor];
                    if (@available(tvOS 13.0, iOS 13.0, *)) {
                        cell.imageView.image = [UIImage systemImageNamed:@"trash"];
                    } else {
                        cell.imageView.image = nil;
                    }
                    break;
            }
            break;
            
        case SettingsSectionEmulators:
            switch (indexPath.row) {
                case EmulatorsRowROMSettings:
                    cell.textLabel.text = @"ROM Settings";
                    cell.textLabel.textColor = [UIColor lightGrayColor]; // Disabled appearance
                    if (@available(tvOS 13.0, iOS 13.0, *)) {
                        cell.imageView.image = [UIImage systemImageNamed:@"folder"];
                    } else {
                        cell.imageView.image = nil;
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    break;
            }
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.section) {
        case SettingsSectionMoonlight:
            switch (indexPath.row) {
                case MoonlightRowOpen:
                    [self openMoonlight];
                    break;
            }
            break;
            
        case SettingsSectionShortcuts:
            switch (indexPath.row) {
                case ShortcutsRowRefresh:
                    [self refreshGames];
                    break;
                case ShortcutsRowClear:
                    [self clearShortcuts];
                    break;
            }
            break;
            
        case SettingsSectionEmulators:
            switch (indexPath.row) {
                case EmulatorsRowROMSettings:
                    // Placeholder - do nothing for now
                    [self showComingSoonAlert];
                    break;
            }
            break;
    }
}

#pragma mark - Actions

- (void)openMoonlight {
    [self dismissViewControllerAnimated:YES completion:^{
        // Create the original Moonlight interface
        UIStoryboard *storyboard;
        
#if TARGET_OS_TV
        storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        // Get the navigation controller which contains MainFrameViewController
        UINavigationController *navController = [storyboard instantiateInitialViewController];
#else
        // For iOS, use the appropriate storyboard
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle:nil];
        } else {
            storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
        }
        UIViewController *mainFrameVC = [storyboard instantiateInitialViewController];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:mainFrameVC];
#endif
        
        // Get the root view controller (should be GameShortcutsViewController)
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        
        // Present the Moonlight interface
        [rootVC presentViewController:navController animated:YES completion:nil];
    }];
}

- (void)clearShortcuts {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear Shortcuts" 
                                                                   message:@"This will remove all saved game shortcuts. You can recreate them by opening Moonlight and connecting to your gaming PC." 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *clearAction = [UIAlertAction actionWithTitle:@"Clear" 
                                                         style:UIAlertActionStyleDestructive 
                                                       handler:^(UIAlertAction * action) {
        GameListManager *manager = [GameListManager sharedManager];
        [manager clearSavedGames];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" 
                                                          style:UIAlertActionStyleCancel 
                                                        handler:nil];
    
    [alert addAction:clearAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)refreshGames {
    // Post notification to trigger a manual refresh
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ManualRefreshGamesRequested" object:nil];
    
    // Show confirmation
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Refreshing Games" 
                                                                   message:@"Scanning for games from your gaming PC..." 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" 
                                                      style:UIAlertActionStyleDefault 
                                                    handler:nil];
    
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showComingSoonAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Coming Soon" 
                                                                   message:@"Emulator ROM settings will be available in a future update." 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" 
                                                      style:UIAlertActionStyleDefault 
                                                    handler:nil];
    
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

@end 