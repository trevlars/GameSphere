//
//  IGDBManager.m
//  Moonlight
//
//  Created by GameSphere on 6/13/25.
//  Copyright © 2025 Moonlight Stream. All rights reserved.
//

#import "IGDBManager.h"

@implementation IGDBManager

+ (instancetype)sharedManager {
    static IGDBManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[IGDBManager alloc] init];
    });
    return sharedInstance;
}

- (void)authenticateWithClientId:(NSString *)clientId 
                    clientSecret:(NSString *)clientSecret 
                      completion:(void(^)(BOOL success, NSError *error))completion {
    
    // Check if we have a valid token
    if ([self isTokenValid]) {
        if (completion) completion(YES, nil);
        return;
    }
    
    // Twitch OAuth endpoint for IGDB
    NSString *urlString = @"https://id.twitch.tv/oauth2/token";
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    NSString *bodyString = [NSString stringWithFormat:@"client_id=%@&client_secret=%@&grant_type=client_credentials",
                           clientId, clientSecret];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) completion(NO, error);
                return;
            }
            
            NSError *jsonError;
            NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            
            if (jsonError || !responseDict[@"access_token"]) {
                NSError *authError = [NSError errorWithDomain:@"IGDBAuthError" 
                                                         code:1001 
                                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse authentication response"}];
                if (completion) completion(NO, authError);
                return;
            }
            
            self.accessToken = responseDict[@"access_token"];
            
            // Calculate expiry date (default to 1 hour if not provided)
            NSNumber *expiresIn = responseDict[@"expires_in"] ?: @3600;
            self.tokenExpiryDate = [NSDate dateWithTimeIntervalSinceNow:[expiresIn doubleValue]];
            
            if (completion) completion(YES, nil);
        });
    }];
    
    [task resume];
}

- (void)searchGameWithName:(NSString *)gameName 
                completion:(void(^)(NSDictionary *gameData, NSError *error))completion {
    
    if (![self isTokenValid]) {
        NSError *error = [NSError errorWithDomain:@"IGDBError" 
                                             code:1002 
                                         userInfo:@{NSLocalizedDescriptionKey: @"No valid access token"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSString *urlString = @"https://api.igdb.com/v4/games";
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"7aj0d5y3mglfxu2ni7mpvy5jg26rkb" forHTTPHeaderField:@"Client-ID"];
    
    // IGDB query to search for games and get cover art
    NSString *query = [NSString stringWithFormat:@"search \"%@\"; fields name,summary,cover.url,cover.image_id,first_release_date,genres.name; limit 1;", gameName];
    [request setHTTPBody:[query dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            
            NSError *jsonError;
            NSArray *responseArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            
            if (jsonError) {
                if (completion) completion(nil, jsonError);
                return;
            }
            
            if (responseArray.count > 0) {
                NSDictionary *gameData = responseArray[0];
                if (completion) completion(gameData, nil);
            } else {
                NSError *notFoundError = [NSError errorWithDomain:@"IGDBError" 
                                                             code:1003 
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Game not found"}];
                if (completion) completion(nil, notFoundError);
            }
        });
    }];
    
    [task resume];
}

- (void)getGameDetailsWithId:(NSNumber *)gameId 
                  completion:(void(^)(NSDictionary *gameData, NSError *error))completion {
    
    if (![self isTokenValid]) {
        NSError *error = [NSError errorWithDomain:@"IGDBError" 
                                             code:1002 
                                         userInfo:@{NSLocalizedDescriptionKey: @"No valid access token"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSString *urlString = @"https://api.igdb.com/v4/games";
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"7aj0d5y3mglfxu2ni7mpvy5jg26rkb" forHTTPHeaderField:@"Client-ID"];
    
    NSString *query = [NSString stringWithFormat:@"where id = %@; fields name,summary,cover.url,cover.image_id,first_release_date,genres.name,screenshots.image_id;", gameId];
    [request setHTTPBody:[query dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            
            NSError *jsonError;
            NSArray *responseArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            
            if (jsonError) {
                if (completion) completion(nil, jsonError);
                return;
            }
            
            if (responseArray.count > 0) {
                NSDictionary *gameData = responseArray[0];
                if (completion) completion(gameData, nil);
            } else {
                NSError *notFoundError = [NSError errorWithDomain:@"IGDBError" 
                                                             code:1003 
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Game not found"}];
                if (completion) completion(nil, notFoundError);
            }
        });
    }];
    
    [task resume];
}

- (void)downloadImageWithURL:(NSString *)imageURL 
                  completion:(void(^)(UIImage *image, NSError *error))completion {
    
    if (!imageURL || imageURL.length == 0) {
        NSError *error = [NSError errorWithDomain:@"IGDBError" 
                                             code:1004 
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid image URL"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:imageURL];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                if (completion) completion(image, nil);
            } else {
                NSError *imageError = [NSError errorWithDomain:@"IGDBError" 
                                                          code:1005 
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to create image from data"}];
                if (completion) completion(nil, imageError);
            }
        });
    }];
    
    [task resume];
}

- (NSString *)constructImageURL:(NSString *)imageId size:(NSString *)size {
    if (!imageId || imageId.length == 0) {
        return nil;
    }
    
    // IGDB image URL format: https://images.igdb.com/igdb/image/upload/t_{size}/{image_id}.jpg
    // Common sizes: thumb (90x128), cover_small (264x374), cover_big (512x512), 1080p (1920x1080)
    return [NSString stringWithFormat:@"https://images.igdb.com/igdb/image/upload/t_%@/%@.jpg", size, imageId];
}

- (BOOL)isTokenValid {
    return self.accessToken && self.tokenExpiryDate && [self.tokenExpiryDate timeIntervalSinceNow] > 300; // 5 minute buffer
}

@end 