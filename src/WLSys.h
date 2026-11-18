//
//  WLSys.h — 无 SDK 环境下的最小声明（只覆盖本工程实际用到的 API）
//  链接时全部走 -undefined dynamic_lookup，运行时由 UIKit / Foundation / libobjc 提供实现。
//
#pragma once
#include <stdarg.h>

#ifndef NULL
#define NULL ((void *)0)
#endif
#ifndef nil
#define nil ((id)0)
#endif
#ifndef Nil
#define Nil ((Class)0)
#endif

#pragma mark - 基础类型

typedef signed char BOOL;
#define YES ((BOOL)1)
#define NO ((BOOL)0)
#ifndef nil
#define nil ((id)0)
#endif
#ifndef Nil
#define Nil ((Class)0)
#endif

typedef long NSInteger;
typedef unsigned long NSUInteger;
typedef double CGFloat;

typedef struct { CGFloat x, y; } CGPoint;
typedef struct { CGFloat width, height; } CGSize;
typedef struct { CGPoint origin; CGSize size; } CGRect;

static inline CGPoint CGPointMake(CGFloat x, CGFloat y) { CGPoint p; p.x = x; p.y = y; return p; }
static inline CGSize CGSizeMake(CGFloat w, CGFloat h) { CGSize s; s.width = w; s.height = h; return s; }
static inline CGRect CGRectMake(CGFloat x, CGFloat y, CGFloat w, CGFloat h) {
    CGRect r; r.origin = CGPointMake(x, y); r.size = CGSizeMake(w, h); return r;
}

typedef struct objc_selector *SEL;
typedef struct objc_class *Class;
typedef struct objc_method *Method;
typedef id (*IMP)(id, SEL, ...);

#pragma mark - objc runtime

Class objc_getClass(const char *name);
const char *class_getName(Class cls);
const char *method_getTypeEncoding(Method m);
int objc_getClassList(Class *buffer, int count);
Class object_getClass(id obj);
Class class_getSuperclass(Class cls);
BOOL class_respondsToSelector(Class cls, SEL sel);
Method class_getInstanceMethod(Class cls, SEL name);
IMP method_getImplementation(Method m);
IMP method_setImplementation(Method m, IMP imp);
SEL sel_registerName(const char *name);
const char *sel_getName(SEL sel);
BOOL sel_isEqual(SEL a, SEL b);
@class NSString;
void NSLog(NSString *format, ...);
NSString *NSHomeDirectory(void);
void *malloc(unsigned long size);
void free(void *ptr);
int getpid(void);

// libc（启动阶段不依赖 ObjC 也要能落盘）
char *getenv(const char *name);
int open(const char *path, int flags, ...);
long write(int fd, const void *buf, unsigned long count);
int close(int fd);
int snprintf(char *buf, unsigned long size, const char *fmt, ...);
unsigned long strlen(const char *s);
#define WL_O_WRONLY 1
#define WL_O_CREAT 0x200
#define WL_O_APPEND 0x8

#pragma mark - dispatch

typedef void *dispatch_queue_t;
typedef unsigned long long dispatch_time_t;
typedef void (^dispatch_block_t)(void);
dispatch_queue_t dispatch_get_main_queue(void);
dispatch_time_t dispatch_time(dispatch_time_t when, long long delta);
void dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);
void dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
#define DISPATCH_TIME_NOW 0ull
#define NSEC_PER_SEC 1000000000ull

#pragma mark - Foundation

typedef NSUInteger NSStringEncoding;
#define NSUTF8StringEncoding 4

@class NSArray, NSDictionary, NSSet, NSDate, NSDateFormatter, NSNumber, NSData;

@interface NSObject {
    Class isa;
}
+ (instancetype)alloc;
+ (instancetype)new;
- (instancetype)init;
- (instancetype)initWithFormat:(NSString *)fmt arguments:(va_list)ap;
- (BOOL)isKindOfClass:(Class)cls;
- (BOOL)respondsToSelector:(SEL)sel;
- (id)valueForKey:(NSString *)key;
- (NSString *)description;
+ (Class)class;
@end

@interface NSString : NSObject
+ (instancetype)stringWithFormat:(NSString *)fmt, ...;
+ (instancetype)stringWithUTF8String:(const char *)s;
+ (instancetype)stringWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(id *)err;
- (NSString *)stringByAppendingPathComponent:(NSString *)comp;
- (NSString *)stringByReplacingOccurrencesOfString:(NSString *)a withString:(NSString *)b;
- (NSArray *)componentsSeparatedByString:(NSString *)sep;
- (BOOL)isEqualToString:(NSString *)s;
- (BOOL)hasPrefix:(NSString *)s;
- (NSData *)dataUsingEncoding:(NSStringEncoding)enc;
- (NSUInteger)length;
- (NSString *)substringFromIndex:(NSUInteger)i;
- (const char *)UTF8String;
@end

@interface NSData : NSObject
- (NSUInteger)length;
@end

@interface NSNumber : NSObject
+ (instancetype)numberWithBool:(BOOL)v;
+ (instancetype)numberWithInt:(int)v;
+ (instancetype)numberWithLong:(long)v;
- (BOOL)boolValue;
- (long)longValue;
@end

@interface NSArray : NSObject
+ (instancetype)array;
+ (instancetype)arrayWithObject:(id)o;
+ (instancetype)arrayWithObjects:(const id *)objects count:(NSUInteger)cnt;
- (NSUInteger)count;
- (id)objectAtIndex:(NSUInteger)i;
- (id)objectAtIndexedSubscript:(NSUInteger)i;
- (BOOL)containsObject:(id)o;
- (NSString *)componentsJoinedByString:(NSString *)sep;
@end

@interface NSMutableArray : NSArray
+ (instancetype)arrayWithCapacity:(NSUInteger)n;
- (void)addObject:(id)o;
@end

@interface NSDictionary : NSObject
+ (instancetype)dictionary;
- (NSUInteger)count;
- (id)objectForKey:(id)k;
- (id)objectForKeyedSubscript:(id)k;
- (NSArray *)allKeys;
@end

@interface NSMutableDictionary : NSDictionary
+ (instancetype)dictionaryWithCapacity:(NSUInteger)n;
- (void)setObject:(id)o forKey:(id)k;
- (void)setObject:(id)o forKeyedSubscript:(id)k;
@end

@interface NSSet : NSObject
- (NSArray *)allObjects;
- (NSUInteger)count;
@end

@interface NSUserDefaults : NSObject
+ (instancetype)standardUserDefaults;
- (instancetype)initWithSuiteName:(NSString *)suite;
- (BOOL)boolValueForKey:(NSString *)k;
- (BOOL)boolForKey:(NSString *)k;
- (id)objectForKey:(NSString *)k;
- (NSArray *)arrayForKey:(NSString *)k;
- (NSString *)stringForKey:(NSString *)k;
- (void)setObject:(id)o forKey:(NSString *)k;
- (void)setBool:(BOOL)b forKey:(NSString *)k;
- (BOOL)synchronize;
@end

@interface NSFileManager : NSObject
+ (instancetype)defaultManager;
- (BOOL)createFileAtPath:(NSString *)path contents:(NSData *)data attributes:(id)attrs;
@end

@interface NSFileHandle : NSObject
+ (instancetype)fileHandleForWritingAtPath:(NSString *)path;
- (unsigned long long)seekToEndOfFile;
- (void)writeData:(NSData *)data;
- (void)closeFile;
@end

@interface NSDate : NSObject
+ (instancetype)date;
@end

@interface NSDateFormatter : NSObject
- (void)setDateFormat:(NSString *)fmt;
- (NSString *)stringFromDate:(NSDate *)d;
@end

#pragma mark - UIKit

typedef NSInteger UIButtonType;
enum { UIButtonTypeCustom = 0 };
typedef unsigned long UIControlEvents;
enum { UIControlEventTouchUpInside = 1 << 6 };
typedef NSInteger UIAlertControllerStyle;
enum { UIAlertControllerStyleActionSheet = 0, UIAlertControllerStyleAlert = 1 };
typedef NSInteger UIAlertActionStyle;
enum { UIAlertActionStyleDefault = 0, UIAlertActionStyleCancel = 1, UIAlertActionStyleDestructive = 2 };
typedef NSInteger UIKeyboardType;
enum { UIKeyboardTypeDefault = 0, UIKeyboardTypeNumberPad = 4 };
typedef NSInteger UIWindowLevel;

@class UIColor, UIFont, UIView, UIViewController, UIScreen, UIWindowScene, UITextField, UILabel, UIWindow;

@interface UIColor : NSObject
+ (UIColor *)clearColor;
+ (UIColor *)whiteColor;
+ (UIColor *)colorWithWhite:(CGFloat)w alpha:(CGFloat)a;
@end

@interface UIFont : NSObject
+ (UIFont *)boldSystemFontOfSize:(CGFloat)size;
+ (UIFont *)systemFontOfSize:(CGFloat)size;
@end

@interface UIScreen : NSObject
+ (UIScreen *)mainScreen;
- (CGRect)bounds;
@end

@interface UIView : NSObject
- (instancetype)initWithFrame:(CGRect)frame;
- (void)setFrame:(CGRect)frame;
- (CGRect)frame;
- (void)setBackgroundColor:(UIColor *)c;
- (void)addSubview:(UIView *)v;
- (void)setAlpha:(CGFloat)a;
- (void)setHidden:(BOOL)h;
- (UIView *)hitTest:(CGPoint)point withEvent:(id)event;
@end

@interface UILabel : UIView
- (void)setFont:(UIFont *)f;
@end

@interface UIButton : UIView
+ (instancetype)buttonWithType:(UIButtonType)type;
- (void)setTitle:(NSString *)t forState:(unsigned long)state;
- (void)setTitleColor:(UIColor *)color forState:(unsigned long)state;
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)events;
- (UILabel *)titleLabel;
@end

@interface UIWindowScene : NSObject
@end

@interface UIApplication : NSObject
+ (UIApplication *)sharedApplication;
- (NSSet *)connectedScenes;
- (NSArray *)windows;
- (UIWindow *)keyWindow;
@end

@interface UIWindow : UIView
- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithWindowScene:(UIWindowScene *)scene;
- (void)setWindowLevel:(UIWindowLevel)level;
- (UIWindowLevel)windowLevel;
- (void)setRootViewController:(UIViewController *)vc;
- (UIViewController *)rootViewController;
- (void)makeKeyAndVisible;
@end

@interface UITextField : UIView
- (void)setText:(NSString *)t;
- (NSString *)text;
- (void)setPlaceholder:(NSString *)p;
- (void)setSecureTextEntry:(BOOL)b;
- (void)setKeyboardType:(UIKeyboardType)t;
@end

@interface UIAlertAction : NSObject
+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style
                        handler:(void (^)(UIAlertAction *action))handler;
@end

@interface UIViewController : NSObject
- (UIView *)view;
- (void)setView:(UIView *)v;
- (void)viewDidLoad;
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)setTitle:(NSString *)t;
- (NSString *)title;
@end

@interface UIAlertController : UIViewController
+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)msg
                          preferredStyle:(UIAlertControllerStyle)style;
- (void)addAction:(UIAlertAction *)action;
- (void)addTextFieldWithConfigurationHandler:(void (^)(UITextField *tf))handler;
- (NSArray *)textFields;
- (void)setTitle:(NSString *)t;
- (NSString *)title;
@end

#define UIWindowLevelAlert 2000
