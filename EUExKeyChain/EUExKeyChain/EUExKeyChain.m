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


#define string_exist_in_info(x) ([info objectForKey:x] && [info[x] isKindOfClass:[NSString class]])



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
NSString * const kUexKeyChainTouchIDPromptKey        =@"iTouchIDPrompt";


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
    NSError *error=nil;
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
    NSError *error=nil;
    BOOL isSuccess=[keyChainItem removeItemForKey:key error:&error];
    [result setValue:@(isSuccess) forKey:kUexKeyChainSuccessKey];
    if(!isSuccess && error){
        [result setValue:@(error.code) forKey:kUexKeyChainErrorCodeKey];
        [result setValue:[error localizedDescription] forKey:kUexKeyChainErrorInfoKey];
    }
    [self callbackJsonWithName:@"cbSetItem" object:result];
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
