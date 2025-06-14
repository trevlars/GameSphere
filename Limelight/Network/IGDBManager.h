//
//  IGDBManager.h
//  Moonlight
//
//  Created by GameSphere on 6/13/25.
//  Copyright © 2025 Moonlight Stream. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface IGDBManager : NSObject

@property (nonatomic, strong) NSString *accessToken;
@property (nonatomic, strong) NSDate *tokenExpiryDate;

+ (instancetype)sharedManager;

// Authentication
- (void)authenticateWithClientId:(NSString *)clientId 
                    clientSecret:(NSString *)clientSecret 
                      completion:(void(^)(BOOL success, NSError *error))completion;

// Game search and metadata
- (void)searchGameWithName:(NSString *)gameName 
                completion:(void(^)(NSDictionary *gameData, NSError *error))completion;

- (void)getGameDetailsWithId:(NSNumber *)gameId 
                  completion:(void(^)(NSDictionary *gameData, NSError *error))completion;

// Image downloading
- (void)downloadImageWithURL:(NSString *)imageURL 
                  completion:(void(^)(UIImage *image, NSError *error))completion;

// Utility methods
- (NSString *)constructImageURL:(NSString *)imageId size:(NSString *)size;
- (BOOL)isTokenValid;

@end 