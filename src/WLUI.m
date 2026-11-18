//
//  WLUI.m — v0.4：不再继承任何 UIKit 类（继承 UIView/UIViewController 会让
//  instanceSize 算错 → 分配过小 → 运行时写爆内存直接闪退）。
//  改成：把按钮直接加到微信现有 keyWindow 的 rootViewController.view 上。
//
#import "WLCommon.h"

static UIWindow *gHostWin = nil;
static UIViewController *gHostVC = nil;
static UIButton *gBtn = nil;
static id gTarget = nil;

static void WLSave(NSString *key, id value) {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:kWLDefaultsSuite];
    [d setObject:value forKey:key];
}
static id WLLoad(NSString *key) {
    return [[[NSUserDefaults alloc] initWithSuiteName:kWLDefaultsSuite] objectForKey:key];
}
static void WLSaveBool(NSString *key, BOOL v) {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:kWLDefaultsSuite];
    [d setBool:v forKey:key];
}
static BOOL WLLoadBool(NSString *key) {
    return [[[NSUserDefaults alloc] initWithSuiteName:kWLDefaultsSuite] boolForKey:key];
}
static NSString *WLJoinList(NSString *key) {
    NSArray *a = WLLoad(key);
    if (!a || ![a isKindOfClass:objc_getClass("NSArray")]) return @"";
    return [a componentsJoinedByString:@","];
}
static void WLSaveListFromText(NSString *key, NSString *text) {
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:8];
    NSArray *parts = [text componentsSeparatedByString:@","];
    for (NSUInteger i = 0; i < [parts count]; i++) {
        NSString *p = [parts objectAtIndex:i];
        NSString *t = [p stringByReplacingOccurrencesOfString:@" " withString:@""];
        if ([t length] > 0) [arr addObject:t];
    }
    WLSave(key, arr);
    WLLog(@"saved %@ -> %lu item(s)", key, (unsigned long)[arr count]);
}

static NSString *OnOff(BOOL on) { return on ? @"开" : @"关"; }

static void WLShowTextEditor(NSString *title, NSString *key, NSString *placeholder) {
    if (!gHostVC) return;
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
                                                               message:placeholder
                                                        preferredStyle:1];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        [tf setText:WLJoinList(key)];
        [tf setPlaceholder:placeholder];
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:1 handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"保存" style:0 handler:^(UIAlertAction *a) {
        UITextField *tf = [[ac textFields] objectAtIndex:0];
        WLSaveListFromText(key, [tf text] ? [tf text] : @"");
    }]];
    [gHostVC presentViewController:ac animated:YES completion:nil];
}

static void WLShowPasswordEditor(void) {
    if (!gHostVC) return;
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"设置密码"
                                                               message:@"留空 = 不设密码"
                                                        preferredStyle:1];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        id p = WLLoad(kWLPassword);
        [tf setText:(p && [p isKindOfClass:objc_getClass("NSString")]) ? p : @""];
        [tf setPlaceholder:@"4-8 位数字"];
        [tf setSecureTextEntry:YES];
        [tf setKeyboardType:4];
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:1 handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"保存" style:0 handler:^(UIAlertAction *a) {
        UITextField *tf = [[ac textFields] objectAtIndex:0];
        WLSave(kWLPassword, [tf text] ? [tf text] : @"");
    }]];
    [gHostVC presentViewController:ac animated:YES completion:nil];
}

static void WLShowMenu(void) {
    if (!gHostVC) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"MiYouHide 隐藏"
                                                                   message:nil
                                                            preferredStyle:0];

    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"总开关：%@", OnOff(WLLoadBool(kWLEnabled))]
                                              style:0 handler:^(UIAlertAction *a) {
        WLSaveBool(kWLEnabled, !WLLoadBool(kWLEnabled));
        WLShowMenu();
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"隐藏好友：%@", OnOff(WLLoadBool(kWLHideFriend))]
                                              style:0 handler:^(UIAlertAction *a) {
        WLSaveBool(kWLHideFriend, !WLLoadBool(kWLHideFriend));
        WLShowMenu();
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"隐藏群/会话：%@", OnOff(WLLoadBool(kWLHideSession))]
                                              style:0 handler:^(UIAlertAction *a) {
        WLSaveBool(kWLHideSession, !WLLoadBool(kWLHideSession));
        WLShowMenu();
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"隐藏朋友圈：%@", OnOff(WLLoadBool(kWLHideMoment))]
                                              style:0 handler:^(UIAlertAction *a) {
        WLSaveBool(kWLHideMoment, !WLLoadBool(kWLHideMoment));
        WLShowMenu();
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"编辑好友名单" style:0 handler:^(UIAlertAction *a) {
        WLShowTextEditor(@"好友名单", kWLHiddenContacts, @"wxid_xxx,wxid_yyy");
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"编辑群名单" style:0 handler:^(UIAlertAction *a) {
        WLShowTextEditor(@"群/会话名单", kWLHiddenSessions, @"123@chatroom");
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"编辑朋友圈名单" style:0 handler:^(UIAlertAction *a) {
        WLShowTextEditor(@"朋友圈名单", kWLHiddenMoments, @"wxid_xxx");
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"设置密码" style:0 handler:^(UIAlertAction *a) {
        WLShowPasswordEditor();
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"隐藏悬浮球：%@", OnOff(WLLoadBool(kWLEntryHidden))]
                                              style:0 handler:^(UIAlertAction *a) {
        WLSaveBool(kWLEntryHidden, !WLLoadBool(kWLEntryHidden));
        if (gBtn) [gBtn setAlpha:WLLoadBool(kWLEntryHidden) ? 0.03 : 1.0];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:1 handler:nil]];
    [gHostVC presentViewController:sheet animated:YES completion:nil];
}

// 唯一自定义类：继承 NSObject（无 ivar，instanceSize=8，与真实 NSObject 一致，安全）
@interface WLTarget : NSObject
- (void)onTap;
@end

@implementation WLTarget
- (void)onTap {
    if (!gHostVC) return;
    id pwd = WLLoad(kWLPassword);
    if (!pwd || ![pwd isKindOfClass:objc_getClass("NSString")] || [(NSString *)pwd length] == 0) {
        WLShowMenu();
        return;
    }
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"输入密码" message:nil preferredStyle:1];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        [tf setSecureTextEntry:YES];
        [tf setKeyboardType:4];
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:1 handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:0 handler:^(UIAlertAction *a) {
        UITextField *tf = [[ac textFields] objectAtIndex:0];
        if ([[tf text] isEqualToString:(NSString *)pwd]) WLShowMenu();
        else WLLog(@"wrong password");
    }]];
    [gHostVC presentViewController:ac animated:YES completion:nil];
}
@end

void WLInstallEntry(void) {
    if (gBtn) { [gBtn setHidden:NO]; return; }

    UIApplication *app = [UIApplication sharedApplication];
    NSArray *wins = [app windows];
    if (!wins) { WLLog(@"entry: no windows"); return; }

    UIWindow *win = nil;
    for (NSUInteger i = 0; i < [wins count]; i++) {
        id w = [wins objectAtIndex:i];
        if ([w isKindOfClass:objc_getClass("UIWindow")]) { win = w; }
    }
    if (!win) { WLLog(@"entry: no UIWindow"); return; }
    gHostWin = win;

    UIViewController *vc = [win rootViewController];
    if (!vc) { WLLog(@"entry: no rootViewController"); return; }
    gHostVC = vc;

    UIView *rootView = [vc view];
    if (!rootView) { WLLog(@"entry: no view"); return; }

    UIButton *btn = [UIButton buttonWithType:0];
    [btn setFrame:CGRectMake(8, 120, 44, 44)];
    [btn setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.35]];
    [btn setTitle:@"隐" forState:0];
    [btn setTitleColor:[UIColor whiteColor] forState:0];
    gTarget = [WLTarget new];
    [btn addTarget:gTarget action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];
    [rootView addSubview:btn];
    gBtn = btn;

    if (WLLoadBool(kWLEntryHidden)) [btn setAlpha:0.03];
    WLLog(@"entry: button added");
}
