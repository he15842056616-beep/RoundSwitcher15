// RoundSwitcher 15  (com.max.roundswitcher15)
//
// STATUS: NOT COMPILED, NOT TESTED ON DEVICE.
// "SBFluidSwitcherItemContainer" is a class name recalled from earlier iOS
// versions. It has NOT been verified on iOS 16.7.16. The heuristics below
// pick the clipping layer at runtime instead of assuming a property name.
// Run the probe (see README) to confirm the real hierarchy.

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <string.h>
#import <notify.h>

static const CGFloat kRS15Radius = 15.0;
static NSString *const kRS15Dir = @"/var/mobile/Library/RoundSwitcher15";
#define RS15_DUMP_NOTIFICATION "com.max.roundswitcher15.dump"

// Minimal declaration only (no header available). Verified at runtime below.
@interface SBFluidSwitcherItemContainer : UIView
@end

#pragma mark - Files / logging

static NSString *RS15Path(NSString *name) {
    return [kRS15Dir stringByAppendingPathComponent:name];
}
static BOOL RS15Exists(NSString *name) {
    return [[NSFileManager defaultManager] fileExistsAtPath:RS15Path(name)];
}
static void RS15Write(NSString *name, NSString *content) {
    [content writeToFile:RS15Path(name) atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
static void RS15Remove(NSString *name) {
    [[NSFileManager defaultManager] removeItemAtPath:RS15Path(name) error:nil];
}

static void RS15Log(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void RS15Log(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[RoundSwitcher15] %@", msg);
    @try {
        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *path = RS15Path(@"log.txt");
        if ([[fm attributesOfItemAtPath:path error:nil] fileSize] > 256 * 1024) {
            [fm removeItemAtPath:path error:nil];
        }
        NSData *line = [[NSString stringWithFormat:@"%@ %@\n", [NSDate date], msg]
                           dataUsingEncoding:NSUTF8StringEncoding];
        NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!h) { [line writeToFile:path atomically:NO]; return; }
        [h seekToEndOfFile];
        [h writeData:line];
        [h closeFile];
    } @catch (NSException *e) {}
}

#pragma mark - Crash-loop guard

// A "pending" marker exists until the process has stayed alive for a while.
// If it is still there at the next launch, the previous run probably crashed.
// Three such launches in a row create the "disable" flag automatically.
static void RS15Arm(NSTimeInterval stableAfter) {
    RS15Write(@"pending", @"1");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(stableAfter * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        RS15Remove(@"pending");
        RS15Remove(@"crashcount");
    });
}

static BOOL RS15ShouldLoad(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtPath:kRS15Dir withIntermediateDirectories:YES attributes:nil error:nil];

    if (RS15Exists(@"disable")) {
        RS15Log(@"disable flag present, not hooking");
        return NO;
    }
    if (RS15Exists(@"pending")) {
        NSString *s = [NSString stringWithContentsOfFile:RS15Path(@"crashcount")
                                                encoding:NSUTF8StringEncoding error:nil];
        NSInteger n = s.integerValue + 1;
        RS15Write(@"crashcount", @(n).stringValue);
        RS15Log(@"previous run did not reach stable state (%ld)", (long)n);
        if (n >= 3) {
            RS15Write(@"disable", @"auto-disabled by crash guard\n");
            RS15Log(@"crash guard tripped, tweak disabled. Use: rs15ctl enable");
            return NO;
        }
    }
    RS15Arm(20.0);
    return YES;
}

#pragma mark - Probe (view hierarchy dump)

static void RS15DumpView(UIView *v, NSInteger depth, NSMutableString *out, NSInteger *lines) {
    if (depth > 10 || *lines > 4000) return;
    CALayer *l = v.layer;
    NSString *indent = [@"" stringByPaddingToLength:(NSUInteger)(depth * 2)
                                         withString:@" " startingAtIndex:0];
    [out appendFormat:@"%@%@ frame=%@ bounds=%@ r=%.1f mask=%d curve=%@ shadowOp=%.2f layer=%@\n",
        indent, NSStringFromClass(v.class), NSStringFromCGRect(v.frame),
        NSStringFromCGRect(v.bounds), l.cornerRadius, (int)l.masksToBounds,
        l.cornerCurve, l.shadowOpacity, NSStringFromClass(l.class)];
    (*lines)++;
    for (UIView *s in v.subviews) RS15DumpView(s, depth + 1, out, lines);
}

static void RS15FindRoots(UIView *v, NSMutableString *out, NSInteger *lines) {
    NSString *cn = NSStringFromClass(v.class);
    if ([cn rangeOfString:@"Switcher" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        RS15DumpView(v, 0, out, lines);   // top-most match: dump subtree, don't descend further
        return;
    }
    for (UIView *s in v.subviews) RS15FindRoots(s, out, lines);
}

static void RS15Dump(void) {
    NSMutableString *out = [NSMutableString stringWithFormat:@"RoundSwitcher15 dump %@\n\n", [NSDate date]];

    [out appendString:@"== Classes in main executable containing 'Switcher' ==\n"];
    unsigned int count = 0;
    const char **names = objc_copyClassNamesForImage(_dyld_get_image_name(0), &count);
    for (unsigned int i = 0; i < count; i++) {
        if (strcasestr(names[i], "Switcher")) [out appendFormat:@"%s\n", names[i]];
    }
    free(names);

    [out appendString:@"\n== View trees rooted at views whose class name contains 'Switcher' ==\n"];
    NSMutableArray<UIWindow *> *wins = [NSMutableArray array];
    for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
        if ([sc isKindOfClass:UIWindowScene.class]) [wins addObjectsFromArray:((UIWindowScene *)sc).windows];
    }
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (![wins containsObject:w]) [wins addObject:w];
    }
    NSInteger lines = 0;
    for (UIWindow *w in wins) RS15FindRoots(w, out, &lines);
    if (lines == 0) [out appendString:@"(no Switcher views reachable from UIApplication windows; open the App Switcher first, or use FLEX)\n"];

    NSString *name = [NSString stringWithFormat:@"dump-%ld.txt", (long)[NSDate date].timeIntervalSince1970];
    RS15Write(name, out);
    RS15Log(@"dump written: %@ (%ld view lines)", name, (long)lines);
}

#pragma mark - Card rounding

// Collect layers that (a) already have a non-zero corner radius and
// (b) are roughly as large as the card container. Header/icon/label views are
// small and are therefore skipped. Nothing is collected if no layer matches.
static void RS15Collect(UIView *container, UIView *node, NSInteger depth, NSMutableArray<CALayer *> *out) {
    CGSize cs = container.bounds.size;
    for (UIView *sub in node.subviews) {
        CGSize s = sub.bounds.size;
        if (s.width >= cs.width * 0.7 && s.height >= cs.height * 0.7 && sub.layer.cornerRadius > 0.0) {
            [out addObject:sub.layer];
        }
        if (depth < 4) RS15Collect(container, sub, depth + 1, out);
    }
}

static void RS15ApplyToContainer(UIView *c) {
    static dispatch_once_t armOnce;
    static NSInteger logged = 0;
    static BOOL dumped = NO;

    if (c.bounds.size.width < 1.0 || c.bounds.size.height < 1.0) return;

    dispatch_once(&armOnce, ^{ RS15Arm(10.0); });

    NSMutableArray<CALayer *> *targets = [NSMutableArray array];
    if (c.layer.cornerRadius > 0.0) [targets addObject:c.layer];
    RS15Collect(c, c, 1, targets);

    for (CALayer *l in targets) {
        if (fabs(l.cornerRadius - kRS15Radius) > 0.01) l.cornerRadius = kRS15Radius;
        if (![l.cornerCurve isEqualToString:kCACornerCurveContinuous]) l.cornerCurve = kCACornerCurveContinuous;
    }

    if (logged < 5) {
        logged++;
        if (targets.count == 0) RS15Log(@"no rounded candidate layer found in %@", NSStringFromClass(c.class));
        else for (CALayer *l in targets) RS15Log(@"rounded layer of class %@ (delegate %@)",
                                                 NSStringFromClass(l.class), NSStringFromClass([l.delegate class]));
    }

    if (!dumped && RS15Exists(@"probe")) {
        dumped = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ @try { RS15Dump(); } @catch (NSException *e) {} });
    }
}

%group Switcher
%hook SBFluidSwitcherItemContainer
- (void)layoutSubviews {
    %orig;
    @try {
        RS15ApplyToContainer((UIView *)self);
    } @catch (NSException *e) {
        RS15Log(@"exception in layoutSubviews hook: %@", e);
    }
}
%end
%end

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        if (!RS15ShouldLoad()) return;

        static int dumpToken;
        notify_register_dispatch(RS15_DUMP_NOTIFICATION, &dumpToken, dispatch_get_main_queue(), ^(int t) {
            @try { RS15Dump(); } @catch (NSException *e) { RS15Log(@"dump failed: %@", e); }
        });

        if (objc_getClass("SBFluidSwitcherItemContainer")) {
            %init(Switcher);
            RS15Log(@"hook on SBFluidSwitcherItemContainer installed");
        } else {
            RS15Log(@"SBFluidSwitcherItemContainer NOT FOUND on this system; probe-only mode");
        }
    }
}
