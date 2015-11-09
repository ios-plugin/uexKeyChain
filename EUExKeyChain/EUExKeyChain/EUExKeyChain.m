//
//  EUExKeyChain.m
//  EUExKeyChain
//
//  Created by CeriNo on 15/11/5.
//  Copyright © 2015年 AppCan. All rights reserved.
//

#import "EUExKeyChain.h"
#import "JSON.h"
#import "EUtility.h"
#import "UICKeyChainStore.h"
#import <LocalAuthentication/LocalAuthentication.h>


#define string_exist_in_info(x) ([info objectForKey:x] && [info[x] isKindOfClass:[NSString class]])
#define boolean_set_true_in_info(x) ([info objectForKey:x] && [info[x] boolValue])
#define iOS8 ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
#define iOS7 ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
#define do_in_background_thread(x) (dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), x))


@implementation EUExKeyChain

NSString * const kUexKeyChainServiceKey              =@"service";
NSString * const kUexKeyChainKeyKey                  =@"key";
NSString * const kUexKeyChainValueKey                =@"value";
NSString * const kUexKeyChainSuccessKey              =@"isSuccess";
NSString * const kUexKeyChainErrorCodeKey            =@"errorCode";
NSString * const kUexKeyChainErrorInfoKey            =@"errorInfo";
NSString * const kUexKeyChainAccessibilityKey        =@"accessibility";
NSString * const kUexKeyChainICloudSyncKey           =@"iCloudSync";
NSString * const kUexKeyChainTouchIDProtectedSyncKey =@"TouchIDProtected";
NSString * const kUexKeyChainTouchIDPromptKey        =@"TouchIDPrompt";


#pragma mark - uexAPIs

-(void)setItem:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return;
    }
    if(!string_exist_in_info(kUexKeyChainKeyKey)||!string_exist_in_info(kUexKeyChainServiceKey)||!string_exist_in_info(kUexKeyChainValueKey)){
        return;
    }
    NSString *service=info[kUexKeyChainServiceKey];
    NSString *key=info[kUexKeyChainKeyKey];
    NSString *value=info[kUexKeyChainValueKey];
    NSMutableDictionary *result =[NSMutableDictionary dictionary];
    [result setValue:key forKey:kUexKeyChainKeyKey];
    [result setValue:service forKey:kUexKeyChainServiceKey];
    UICKeyChainStore *keyChainItem=[UICKeyChainStore keyChainStoreWithService:service];
    do_in_background_thread(^{
        
        if(boolean_set_true_in_info(kUexKeyChainTouchIDProtectedSyncKey) && [self isTouchIDAvailable]){
            [keyChainItem setAccessibility:UICKeyChainStoreAccessibilityWhenPasscodeSetThisDeviceOnly
                  authenticationPolicy:UICKeyChainStoreAuthenticationPolicyUserPresence];
            
        }else{
            UICKeyChainStoreAccessibility accessibility = UICKeyChainStoreAccessibilityAfterFirstUnlock;
            if([info objectForKey:kUexKeyChainAccessibilityKey]){
                accessibility = [self parseAccessibility:[info[kUexKeyChainAccessibilityKey] integerValue]];
            }
            [keyChainItem setAccessibility:accessibility];
            if(boolean_set_true_in_info(kUexKeyChainICloudSyncKey)){
                keyChainItem.synchronizable=YES;
            }
        }
        if(string_exist_in_info(kUexKeyChainTouchIDPromptKey)){
            keyChainItem.authenticationPrompt=info[kUexKeyChainTouchIDPromptKey];
        }

        NSError *error=nil;
        BOOL isSuccess=[keyChainItem setString:value forKey:key error:&error];
        [result setValue:@(isSuccess) forKey:kUexKeyChainSuccessKey];
        if(isSuccess){
            [result setValue:value forKey:kUexKeyChainValueKey];
        }else if(error){
            [result setValue:@(error.code) forKey:kUexKeyChainErrorCodeKey];
            [result setValue:[error localizedDescription] forKey:kUexKeyChainErrorInfoKey];
        }
        [self callbackJsonWithName:@"cbSetItem" object:result];
    });
   
}

-(void)getItem:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return;
    }
    if(!string_exist_in_info(kUexKeyChainKeyKey)||!string_exist_in_info(kUexKeyChainServiceKey)){
        return;
    }
    NSString *service=info[kUexKeyChainServiceKey];
    NSString *key=info[kUexKeyChainKeyKey];
    NSMutableDictionary *result =[NSMutableDictionary dictionary];
    [result setValue:key forKey:kUexKeyChainKeyKey];
    [result setValue:service forKey:kUexKeyChainServiceKey];
     UICKeyChainStore *keyChainItem=[UICKeyChainStore keyChainStoreWithService:service];

    do_in_background_thread(^{
        NSError *error=nil;
        [keyChainItem setAccessibility:UICKeyChainStoreAccessibilityWhenPasscodeSetThisDeviceOnly
                  authenticationPolicy:UICKeyChainStoreAuthenticationPolicyUserPresence];
        if(string_exist_in_info(kUexKeyChainTouchIDPromptKey)){
            keyChainItem.authenticationPrompt=info[kUexKeyChainTouchIDPromptKey];
        }
        NSString * value=[keyChainItem stringForKey:key error:&error];
        if(!error && value){
            [result setValue:value forKey:kUexKeyChainValueKey];
            [result setValue:@(YES) forKey:kUexKeyChainSuccessKey];
        }else{
            [result setValue:@(NO) forKey:kUexKeyChainSuccessKey];
            if(error){
                
                [result setValue:@(error.code) forKey:kUexKeyChainErrorCodeKey];
                [result setValue:[error localizedDescription] forKey:kUexKeyChainErrorInfoKey];
            }
        }
        [self callbackJsonWithName:@"cbGetItem" object:result];
    });

}


-(void)removeItem:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return;
    }
    if(!string_exist_in_info(kUexKeyChainKeyKey)||!string_exist_in_info(kUexKeyChainServiceKey)){
        return;
    }
    NSString *service=info[kUexKeyChainServiceKey];
    NSString *key=info[kUexKeyChainKeyKey];
    NSMutableDictionary *result =[NSMutableDictionary dictionary];
    [result setValue:key forKey:kUexKeyChainKeyKey];
    [result setValue:service forKey:kUexKeyChainServiceKey];
    UICKeyChainStore *keyChainItem=[UICKeyChainStore keyChainStoreWithService:service];
    do_in_background_thread(^{
        NSError *error=nil;

        BOOL isSuccess=[keyChainItem removeItemForKey:key error:&error];
        [result setValue:@(isSuccess) forKey:kUexKeyChainSuccessKey];
        if(!isSuccess && error){
            [result setValue:@(error.code) forKey:kUexKeyChainErrorCodeKey];
            [result setValue:[error localizedDescription] forKey:kUexKeyChainErrorInfoKey];
        }
        [self callbackJsonWithName:@"cbSetItem" object:result];
    });
    
}

#pragma mark - private method

-(BOOL)isTouchIDAvailable{
    LAContext *context = [[LAContext alloc] init];
    return ([context canEvaluatePolicy: LAPolicyDeviceOwnerAuthenticationWithBiometrics error:NULL] && iOS8);
}



-(UICKeyChainStoreAccessibility)parseAccessibility:(NSInteger)accessibility{
    switch (accessibility) {
        case 0 : {
            return UICKeyChainStoreAccessibilityAlways;
            break;
        }
        case 1 : {
            return UICKeyChainStoreAccessibilityAlwaysThisDeviceOnly;
            break;
        }
        case 2 : {
            return UICKeyChainStoreAccessibilityAfterFirstUnlock;
            break;
        }
        case 3 : {
            return UICKeyChainStoreAccessibilityAfterFirstUnlockThisDeviceOnly;
            break;
        }
        case 4 : {
            return UICKeyChainStoreAccessibilityWhenUnlocked;
            break;
        }
        case 5 : {
            return UICKeyChainStoreAccessibilityWhenUnlockedThisDeviceOnly;
            break;
        }
        case 6 : {
            if(iOS8){
                return UICKeyChainStoreAccessibilityWhenPasscodeSetThisDeviceOnly;
            }
            break;
        }
            
            
        default:
            break;
    }
    return UICKeyChainStoreAccessibilityAfterFirstUnlock;
}

#pragma mark - callback

-(void)callbackJsonWithName:(NSString *)name object:(id<NSCopying,NSCoding>)obj{
    [EUtility uexPlugin:@"uexKeyChain"
         callbackByName:name
             withObject:obj
                andType:uexPluginCallbackWithJsonString
               inTarget:self.meBrwView];
}


@end
