#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>
int main(void){ @autoreleasepool {
  NSDictionary* q = @{(__bridge NSString*)kTISPropertyInputSourceCategory:(__bridge NSString*)kTISCategoryKeyboardInputSource};
  CFArrayRef all = TISCreateInputSourceList((__bridge CFDictionaryRef)q, false);
  for (id s in (__bridge NSArray*)all) {
    TISInputSourceRef r=(__bridge TISInputSourceRef)s;
    NSString* i=(__bridge NSString*)TISGetInputSourceProperty(r,kTISPropertyInputSourceID);
    NSString* t=(__bridge NSString*)TISGetInputSourceProperty(r,kTISPropertyInputSourceType);
    CFBooleanRef sel=TISGetInputSourceProperty(r,kTISPropertyInputSourceIsSelectCapable);
    printf("enabled: %s type=%s selectable=%d\n", i.UTF8String, t.UTF8String, sel?CFBooleanGetValue(sel):-1);
  }
  TISInputSourceRef cur=TISCopyCurrentKeyboardInputSource();
  printf("current: %s\n", [(__bridge NSString*)TISGetInputSourceProperty(cur,kTISPropertyInputSourceID) UTF8String]);
}}
