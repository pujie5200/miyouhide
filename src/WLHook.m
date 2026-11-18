//
//  WLHook.m — 密友（MiYouHide）核心：日志 / 配置 / 过滤 / hook 引擎
//  设计要点：
//   1. constructor 里只做纯 C 落盘（不碰 ObjC 运行时）
//   2. 所有 hook 都以「self, _cmd, 3 个透传参数」的形式转发给原始 IMP，
//      避免参数个数猜错导致寄存器被自己代码破坏（上一版崩溃的根因之一）
//   3. 运行时扫描所有实现目标 selector 的类，逐个 swizzle（不硬编码类名，抗版本）
//
#import "WLCommon.h"

#pragma mark - C 级启动日志

static int gFd = -1;
static char gPath[512];

static void WLBoot(const char *msg) {
    if (gFd < 0) {
        const char *home = getenv("HOME");
        if (!home) return;
        snprintf(gPath, sizeof(gPath), "%s/Documents/MiYouHide.log", home);
        gFd = open(gPath, WL_O_WRONLY | WL_O_CREAT | WL_O_APPEND, 0644);
    }
    if (gFd >= 0) {
        write(gFd, msg, strlen(msg));
        write(gFd, "\n", 1);
    }
}

void WLLog(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[MiYouHide] %@", msg);
    WLBoot([msg UTF8String]);
}

#pragma mark - 配置

static NSUserDefaults *WLDefs = nil;

static NSUserDefaults *WLDefaults(void) {
    if (!WLDefs) {
        WLDefs = [[NSUserDefaults alloc] initWithSuiteName:kWLDefaultsSuite];
        if (!WLDefs) WLDefs = [NSUserDefaults standardUserDefaults];
    }
    return WLDefs;
}

BOOL WLOn(NSString *key) { return [WLDefaults() boolForKey:key]; }

NSArray *WLHiddenList(NSString *key) {
    id v = [WLDefaults() arrayForKey:key];
    if (v && [v isKindOfClass:objc_getClass("NSArray")]) return v;
    return [NSArray array];
}

#pragma mark - 用户名提取

NSString *WLUserName(id obj) {
    if (!obj) return nil;
    if ([obj isKindOfClass:objc_getClass("NSString")]) return obj;
    const char *keys[] = {"m_nsUsrName", "m_nsUserName", "m_nsNickName",
                          "usrName", "userName", "nickName", "m_nsRemark"};
    int n = (int)(sizeof(keys) / sizeof(keys[0]));
    for (int i = 0; i < n; i++) {
        @try {
            id v = [obj valueForKey:[NSString stringWithUTF8String:keys[i]]];
            if (v && [v isKindOfClass:objc_getClass("NSString")]) {
                NSString *s = (NSString *)v;
                if ([s length] > 0) return s;
            }
        } @catch (id e) { (void)e; }
    }
    return nil;
}

BOOL WLIsHidden(id obj, NSString *key) {
    if (!WLOn(kWLEnabled)) return NO;
    NSArray *list = WLHiddenList(key);
    if ([list count] == 0) return NO;
    NSString *u = WLUserName(obj);
    if (u && [list containsObject:u]) return YES;
    return NO;
}

NSArray *WLFilterArray(NSArray *arr, NSString *key) {
    if (!arr || ![arr isKindOfClass:objc_getClass("NSArray")]) return arr;
    NSUInteger n = [arr count];
    if (n == 0 || !WLOn(kWLEnabled)) return arr;
    NSArray *list = WLHiddenList(key);
    if ([list count] == 0) return arr;

    NSMutableArray *out = [NSMutableArray arrayWithCapacity:n];
    NSUInteger removed = 0;
    for (NSUInteger i = 0; i < n; i++) {
        id o = [arr objectAtIndex:i];
        NSString *u = WLUserName(o);
        if (u && [list containsObject:u]) { removed++; continue; }
        [out addObject:o];
    }
    if (removed) WLLog(@"filter %@: %lu -> %lu", key, (unsigned long)n, (unsigned long)[out count]);
    return removed ? out : arr;
}

NSDictionary *WLFilterDict(NSDictionary *dict, NSString *key) {
    if (!dict || ![dict isKindOfClass:objc_getClass("NSDictionary")]) return dict;
    if (!WLOn(kWLEnabled)) return dict;
    NSArray *list = WLHiddenList(key);
    if ([list count] == 0) return dict;

    NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:[dict count]];
    NSArray *keys = [dict allKeys];
    for (NSUInteger i = 0; i < [keys count]; i++) {
        id k = [keys objectAtIndex:i];
        id v = [dict objectForKey:k];
        if ([k isKindOfClass:objc_getClass("NSString")] && [list containsObject:k]) continue;
        NSString *u = WLUserName(v);
        if (u && [list containsObject:u]) continue;
        [out setObject:v forKey:k];
    }
    return out;
}

#pragma mark - hook 引擎

typedef struct { Class cls; SEL sel; IMP orig; } WLSlot;
static WLSlot g_slots[256];
static int g_slotCount = 0;

static IMP WLOrigIMP(id self, SEL sel) {
    Class c = object_getClass(self);
    for (Class k = c; k; k = class_getSuperclass(k)) {
        for (int i = 0; i < g_slotCount; i++) {
            if (g_slots[i].cls == k && sel_isEqual(g_slots[i].sel, sel)) return g_slots[i].orig;
        }
    }
    return NULL;
}

static int WLSwizzle(SEL sel, IMP newImp) {
    int n = objc_getClassList(NULL, 0);
    if (n <= 0) return 0;
    Class *classes = (Class *)malloc(sizeof(Class) * (NSUInteger)n);
    if (!classes) return 0;
    n = objc_getClassList(classes, n);
    int hit = 0;
    for (int i = 0; i < n; i++) {
        Class cls = classes[i];
        if (!class_respondsToSelector(cls, sel)) continue;
        Method m = class_getInstanceMethod(cls, sel);
        if (!m) continue;
        IMP orig = method_getImplementation(m);
        if (orig == newImp) continue;
        if (g_slotCount < 256) {
            g_slots[g_slotCount].cls = cls;
            g_slots[g_slotCount].sel = sel;
            g_slots[g_slotCount].orig = orig;
            g_slotCount++;
        }
        method_setImplementation(m, newImp);
        hit++;
    }
    free(classes);
    WLLog(@"swizzle [%s] -> %d class(es)", sel_getName(sel), hit);
    return hit;
}

#pragma mark - 具体钩子（透传 3 个参数，不猜签名）

static id WL_getContactList(id self, SEL _cmd, id a1, long a2, long a3) {
    IMP o = WLOrigIMP(self, _cmd);
    if (!o) return nil;
    id r = ((id (*)(id, SEL, id, long, long))o)(self, _cmd, a1, a2, a3);
    return WLFilterArray(r, kWLHiddenContacts);
}

static id WL_getDicContacts(id self, SEL _cmd, id a1, long a2, long a3) {
    IMP o = WLOrigIMP(self, _cmd);
    if (!o) return nil;
    id r = ((id (*)(id, SEL, id, long, long))o)(self, _cmd, a1, a2, a3);
    return WLFilterDict(r, kWLHiddenContacts);
}

static BOOL WL_isInMyContactList(id self, SEL _cmd, id a1, long a2, long a3) {
    if (WLIsHidden(a1, kWLHiddenContacts)) return NO;
    IMP o = WLOrigIMP(self, _cmd);
    if (!o) return NO;
    return ((BOOL (*)(id, SEL, id, long, long))o)(self, _cmd, a1, a2, a3);
}

static id WL_GetSessionInfoList(id self, SEL _cmd, id a1, long a2, long a3) {
    IMP o = WLOrigIMP(self, _cmd);
    if (!o) return nil;
    id r = ((id (*)(id, SEL, id, long, long))o)(self, _cmd, a1, a2, a3);
    return WLFilterArray(r, kWLHiddenSessions);
}

static id WL_getSessionInfoList(id self, SEL _cmd, id a1, long a2, long a3) {
    IMP o = WLOrigIMP(self, _cmd);
    if (!o) return nil;
    id r = ((id (*)(id, SEL, id, long, long))o)(self, _cmd, a1, a2, a3);
    return WLFilterArray(r, kWLHiddenSessions);
}

static BOOL WL_hasSharedGroup(id self, SEL _cmd, id a1, long a2, long a3) {
    if (WLIsHidden(a1, kWLHiddenMoments) || WLIsHidden(self, kWLHiddenMoments)) return NO;
    IMP o = WLOrigIMP(self, _cmd);
    if (!o) return NO;
    return ((BOOL (*)(id, SEL, id, long, long))o)(self, _cmd, a1, a2, a3);
}

#pragma mark - 诊断 + 安装

static void WLInspect(void) {
    const char *sels[] = {
        "getContactList:contactType:", "getDicContacts", "isInMyContactList",
        "GetSessionInfoList", "getSessionInfoList", "hasSharedGroup",
    };
    int nsel = (int)(sizeof(sels) / sizeof(sels[0]));
    int n = objc_getClassList(NULL, 0);
    WLLog(@"inspect: %d classes", n);
    if (n <= 0) return;
    Class *classes = (Class *)malloc(sizeof(Class) * (NSUInteger)n);
    if (!classes) return;
    n = objc_getClassList(classes, n);
    for (int s = 0; s < nsel; s++) {
        SEL sel = sel_registerName(sels[s]);
        int count = 0;
        for (int i = 0; i < n; i++) {
            Class cls = classes[i];
            if (!class_respondsToSelector(cls, sel)) continue;
            Method m = class_getInstanceMethod(cls, sel);
            if (!m) continue;
            const char *enc = method_getTypeEncoding(m);
            if (count < 8) WLLog(@"  [%s] %s enc=%s", sels[s], class_getName(cls), enc ? enc : "?");
            count++;
        }
        WLLog(@"selector %s -> %d impl(s)", sels[s], count);
    }
    free(classes);
}

static void WLInstallHooks(void) {
    int total = 0;
    total += WLSwizzle(sel_registerName("getContactList:contactType:"), (IMP)WL_getContactList);
    total += WLSwizzle(sel_registerName("getDicContacts"), (IMP)WL_getDicContacts);
    total += WLSwizzle(sel_registerName("isInMyContactList"), (IMP)WL_isInMyContactList);
    total += WLSwizzle(sel_registerName("GetSessionInfoList"), (IMP)WL_GetSessionInfoList);
    total += WLSwizzle(sel_registerName("getSessionInfoList"), (IMP)WL_getSessionInfoList);
    total += WLSwizzle(sel_registerName("hasSharedGroup"), (IMP)WL_hasSharedGroup);
    WLLog(@"hooks installed: %d method(s)", total);
}

__attribute__((constructor)) static void WLInit(void) {
    WLBoot("S0: constructor (pure C)");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (long long)(2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WLBoot("S1: main queue alive");
        WLInspect();
        WLInstallHooks();
        WLInstallEntry();
        WLBoot("S6: all done");
    });
}
