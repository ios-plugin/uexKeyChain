//
//  EUExKeyChain.m
//  EUExKeyChain
//
//  Created by CeriNo on 15/11/5.
//  Copyright © 2015年 AppCan. All rights reserved.
//

#import "EUExKeyChain.h"
#import "UICKeyChainStore.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <AppCanKit/ACEXTScope.h>


#define boolean_set_true_in_info(x) (info[x] && [info[x] boolValue])

#define do_in_background_thread(x) (dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), x))




@implementation EUExKeyChain

static NSString * const kUexKeyChainDeviceUniqueIdentifierService = @"uexKeyChainDeviceUniqueIdentifierService";
static NSString * const kUexKeyChainDeviceUniqueIdentifierKey     = @"uexKeyChainDeviceUniqueIdentifierKey";
static NSString * const kUexKeyChainServiceKey                    = @"service";
static NSString * const kUexKeyChainKeyKey                        = @"key";
static NSString * const kUexKeyChainValueKey                      = @"value";
static NSString * const kUexKeyChainSuccessKey                    = @"isSuccess";
static NSString * const kUexKeyChainErrorCodeKey                  = @"errorCode";
static NSString * const kUexKeyChainErrorInfoKey                  = @"errorInfo";
static NSString * const kUexKeyChainAccessibilityKey              = @"accessibility";
static NSString * const kUexKeyChainICloudSyncKey                 = @"iCloudSync";
static NSString * const kUexKeyChainTouchIDProtectedSyncKey       = @"TouchIDProtected";
static NSString * const kUexKeyChainTouchIDPromptKey              = @"TouchIDPrompt";


static inline NSError * argumentError(void){
    return [NSError errorWithDomain:@"com.appcan.uexKeyChain" code:1 userInfo:@{NSLocalizedDescriptionKey:@"invalid arguments"}];
}
static inline NSString * cbKeyPath(NSString *funcName){
    return [NSString stringWithFormat:@"uexKeyChain.%@",funcName];
}



#pragma mark - uexAPIs

- (void)setItem:(NSMutableArray *)inArguments{
    
    ACLogDebug(@"%@",NSStringFromSelector(_cmd));
    
    ACArgsUnpack(NSDictionary *info,ACJSFunctionRef *cb) = inArguments;

    NSString *service = stringArg(info[kUexKeyChainServiceKey]);
    NSString *key = stringArg(info[kUexKeyChainKeyKey]);
    NSString *value = stringArg(info[kUexKeyChainValueKey]);
    
    void (^callback)(BOOL isSuccess,NSError *error) = ^(BOOL isSuccess,NSError *error){
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@(isSuccess) forKey:kUexKeyChainSuccessKey];
        [dict setValue:key forKey:kUexKeyChainKeyKey];
        [dict setValue:service forKey:kUexKeyChainServiceKey];
        if(isSuccess){
            [dict setValue:value forKey:kUexKeyChainValueKey];
        }else if(error){
            [dict setValue:@(error.code) forKey:kUexKeyChainErrorCodeKey];
            [dict setValue:[error localizedDescription] forKey:kUexKeyChainErrorInfoKey];
        }
        [self.webViewEngine callbackWithFunctionKeyPath:cbKeyPath(@"cbSetItem") arguments:ACArgsPack(dict.ac_JSONFragment)];
        [cb executeWithArguments:ACArgsPack(dict)];
    };
    
    
    if (!service || !key || !value) {
        callback(NO,argumentError());
        return;
    }
    
    UICKeyChainStore *keyChainItem=[UICKeyChainStore keyChainStoreWithService:service];
    do_in_background_thread(^{
        if(boolean_set_true_in_info(kUexKeyChainTouchIDProtectedSyncKey) && [self isTouchIDAvailable]){
            [keyChainItem setAccessibility:UICKeyChainStoreAccessibilityWhenPasscodeSetThisDeviceOnly
                  authenticationPolicy:UICKeyChainStoreAuthenticationPolicyUserPresence];
            
        }else{
            UICKeyChainStoreAccessibility accessibility = UICKeyChainStoreAccessibilityAfterFirstUnlock;
            NSNumber *accessNum = numberArg(info[kUexKeyChainAccessibilityKey]);
            if (accessNum) {
                accessibility = [self accessibilityFromInteger:accessNum.integerValue];
            }
            [keyChainItem setAccessibility:accessibility];
            if(boolean_set_true_in_info(kUexKeyChainICloudSyncKey)){
                keyChainItem.synchronizable = YES;
            }
        }
        NSString * authenticationPrompt = stringArg(info[kUexKeyChainTouchIDPromptKey]);
        if(authenticationPrompt && [self isTouchIDAvailable]){
            keyChainItem.authenticationPrompt = authenticationPrompt;
        }

        NSError *error = nil;
        BOOL isSuccess = [keyChainItem setString:value forKey:key error:&error];
        callback(isSuccess,error);
    });
   
}

- (void)getItem:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info,ACJSFunctionRef *cb) = inArguments;

    NSString *service = stringArg(info[kUexKeyChainServiceKey]);
    NSString *key = stringArg(info[kUexKeyChainKeyKey]);
    __block NSString *value = nil;
    
    void (^callback)(BOOL isSuccess,NSError *error) = ^(BOOL isSuccess,NSError *error){
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@(isSuccess) forKey:kUexKeyChainSuccessKey];
        [dict setValue:key forKey:kUexKeyChainKeyKey];
        [dict setValue:service forKey:kUexKeyChainServiceKey];
        if(isSuccess){
            [dict setValue:value forKey:kUexKeyChainValueKey];
        }else if(error){
            [dict setValue:@(error.code) forKey:kUexKeyChainErrorCodeKey];
            [dict setValue:[error localizedDescription] forKey:kUexKeyChainErrorInfoKey];
        }
        [self.webViewEngine callbackWithFunctionKeyPath:cbKeyPath(@"cbGetItem") arguments:ACArgsPack(dict.ac_JSONFragment)];
        [cb executeWithArguments:ACArgsPack(dict)];
    };
    
    if (!key || !service) {
        callback(NO,argumentError());
        return;
    }
    
    do_in_background_thread(^{
        UICKeyChainStore *keyChainItem=[UICKeyChainStore keyChainStoreWithService:service];
        NSError *error=nil;
        NSString * authenticationPrompt = stringArg(info[kUexKeyChainTouchIDPromptKey]);
        if(authenticationPrompt && [self isTouchIDAvailable]){
            keyChainItem.authenticationPrompt = authenticationPrompt;
        }
        value = [keyChainItem stringForKey:key error:&error];
        BOOL isSuccess = value && !error;
        callback(isSuccess,error);
    });

}


- (void)removeItem:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info,ACJSFunctionRef *cb) = inArguments;
    
    NSString *service = stringArg(info[kUexKeyChainServiceKey]);
    NSString *key = stringArg(info[kUexKeyChainKeyKey]);


    void (^callback)(BOOL isSuccess,NSError *error) = ^(BOOL isSuccess,NSError *error){
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@(isSuccess) forKey:kUexKeyChainSuccessKey];
        [dict setValue:key forKey:kUexKeyChainKeyKey];
        [dict setValue:service forKey:kUexKeyChainServiceKey];
        if(!isSuccess && error){
            [dict setValue:@(error.code) forKey:kUexKeyChainErrorCodeKey];
            [dict setValue:[error localizedDescription] forKey:kUexKeyChainErrorInfoKey];
        }
        [self.webViewEngine callbackWithFunctionKeyPath:cbKeyPath(@"cbRemoveItem") arguments:ACArgsPack(dict.ac_JSONFragment)];
        [cb executeWithArguments:ACArgsPack(dict)];
    };
    
    
    if (!service || !key) {
        callback(NO,argumentError());
    }
    
    do_in_background_thread(^{
        UICKeyChainStore *keyChainItem=[UICKeyChainStore keyChainStoreWithService:service];
        NSError *error=nil;
        BOOL isSuccess=[keyChainItem removeItemForKey:key error:&error];
        callback(isSuccess,error);
    });
}


- (NSString *)getDeviceUniqueIdentifier:(NSMutableArray *)inArguments{
    
    UICKeyChainStore *keychainItem = [UICKeyChainStore keyChainStoreWithService:kUexKeyChainDeviceUniqueIdentifierService];
    __block NSString *uid = [keychainItem stringForKey:kUexKeyChainDeviceUniqueIdentifierKey];

    if (uid.length < 32) {
        uid = [NSUUID UUID].UUIDString;
        uid = [uid stringByReplacingOccurrencesOfString:@"-" withString:@""];
        [keychainItem setAccessibility:UICKeyChainStoreAccessibilityAfterFirstUnlockThisDeviceOnly];
        NSError *error;
        [keychainItem setString:uid forKey:kUexKeyChainDeviceUniqueIdentifierKey error:&error];
        if (error) {
            uid = @"";
        }
    }
    [self.webViewEngine callbackWithFunctionKeyPath:cbKeyPath(@"cbGetDeviceUniqueIdentifier") arguments:ACArgsPack(@{@"uid":uid})];
    return uid;
}

#pragma mark - private method

- (BOOL)isTouchIDAvailable{
    static BOOL isTouchIDAvailable = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!NSClassFromString(@"LAContext") || ACSystemVersion() < 8.0) {
            return;
        }
        LAContext *context = [[LAContext alloc] init];
        isTouchIDAvailable = ([context canEvaluatePolicy: LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil]);
    });
    return isTouchIDAvailable;

}



- (UICKeyChainStoreAccessibility)accessibilityFromInteger:(NSInteger)accessibility{
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
            if(ACSystemVersion() >= 8.0){
                return UICKeyChainStoreAccessibilityWhenPasscodeSetThisDeviceOnly;
            }
            break;
        }
            
            
        default:
            break;
    }
    return UICKeyChainStoreAccessibilityAfterFirstUnlock;
}



@end
