//
//  WLCommon.h — MiYouHide 公共定义（无 SDK 版，依赖 WLSys.h 的最小声明）
//
#pragma once
#import "WLSys.h"

#ifdef __cplusplus
extern "C" {
#endif

void WLLog(NSString *fmt, ...);
BOOL WLOn(NSString *key);
NSString *WLUserName(id obj);
NSArray *WLHiddenList(NSString *key);
BOOL WLIsHidden(id obj, NSString *key);
NSArray *WLFilterArray(NSArray *arr, NSString *key);
NSDictionary *WLFilterDict(NSDictionary *dict, NSString *key);
void WLInstallEntry(void);

#ifdef __cplusplus
}
#endif

// 配置键
#define kWLEnabled        @"enabled"
#define kWLHideFriend     @"hideFriend"
#define kWLHideSession    @"hideSession"
#define kWLHideMoment     @"hideMoment"
#define kWLHiddenContacts @"hiddenContacts"
#define kWLHiddenSessions @"hiddenSessions"
#define kWLHiddenMoments  @"hiddenMoments"
#define kWLPassword       @"password"
#define kWLEntryHidden    @"entryHidden"

#define kWLDefaultsSuite  @"com.MiYouHide.settings"
