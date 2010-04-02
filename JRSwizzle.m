/*******************************************************************************
  JRSwizzle.m
    Copyright (c) 2007 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
    Some rights reserved: <http://opensource.org/licenses/mit-license.php>

  ***************************************************************************/

#import "JRSwizzle.h"
#import <objc/objc-class.h>

#define SetNSError(ERROR_VAR, FORMAT,...) \
  if (ERROR_VAR) {  \
    NSString *errStr = [@"+[NSObject(JRSwizzle) jr_swizzleMethod:withMethod:error:]: " stringByAppendingFormat:FORMAT,##__VA_ARGS__]; \
    *ERROR_VAR = [NSError errorWithDomain:@"NSCocoaErrorDomain" \
                     code:-1  \
                   userInfo:[NSDictionary dictionaryWithObject:errStr forKey:NSLocalizedDescriptionKey]]; \
  }

@implementation NSObject (JRSwizzle)

+ (BOOL)jr_swizzleMethod:(SEL)origSel_ withMethod:(SEL)altSel_ error:(NSError**)error_ {
#if OBJC_API_VERSION >= 2
  Method origMethod = class_getInstanceMethod(self, origSel_);
  if (!origMethod) {
    SetNSError(error_, @"original method %@ not found for class %@", NSStringFromSelector(origSel_), [self className]);
    return NO;
  }
  
  Method altMethod = class_getInstanceMethod(self, altSel_);
  if (!altMethod) {
    SetNSError(error_, @"alternate method %@ not found for class %@", NSStringFromSelector(altSel_), [self className]);
    return NO;
  }
  
  class_addMethod(self,
          origSel_,
          class_getMethodImplementation(self, origSel_),
          method_getTypeEncoding(origMethod));
  class_addMethod(self,
          altSel_,
          class_getMethodImplementation(self, altSel_),
          method_getTypeEncoding(altMethod));
  
  method_exchangeImplementations(class_getInstanceMethod(self, origSel_), class_getInstanceMethod(self, altSel_));
  return YES;
#else
  //  Scan for non-inherited methods.
  Method directOriginalMethod = NULL, directAlternateMethod = NULL;
  
  void *iterator = NULL;
  struct objc_method_list *mlist = class_nextMethodList(self, &iterator);
  while (mlist) {
    int method_index = 0;
    for (; method_index < mlist->method_count; method_index++) {
      if (mlist->method_list[method_index].method_name == origSel_) {
        assert(!directOriginalMethod);
        directOriginalMethod = &mlist->method_list[method_index];
      }
      if (mlist->method_list[method_index].method_name == altSel_) {
        assert(!directAlternateMethod);
        directAlternateMethod = &mlist->method_list[method_index];
      }
    }
    mlist = class_nextMethodList(self, &iterator);
  }
  
  //  If either method is inherited, copy it up to the target class to make it non-inherited.
  if (!directOriginalMethod || !directAlternateMethod) {
    Method inheritedOriginalMethod = NULL, inheritedAlternateMethod = NULL;
    if (!directOriginalMethod) {
      inheritedOriginalMethod = class_getInstanceMethod(self, origSel_);
      if (!inheritedOriginalMethod) {
        SetNSError(error_, @"original method %@ not found for class %@", NSStringFromSelector(origSel_), [self className]);
        return NO;
      }
    }
    if (!directAlternateMethod) {
      inheritedAlternateMethod = class_getInstanceMethod(self, altSel_);
      if (!inheritedAlternateMethod) {
        SetNSError(error_, @"alternate method %@ not found for class %@", NSStringFromSelector(altSel_), [self className]);
        return NO;
      }
    }
    
    int hoisted_method_count = !directOriginalMethod && !directAlternateMethod ? 2 : 1;
    struct objc_method_list *hoisted_method_list = malloc(sizeof(struct objc_method_list) + (sizeof(struct objc_method)*(hoisted_method_count-1)));
    hoisted_method_list->method_count = hoisted_method_count;
    Method hoisted_method = hoisted_method_list->method_list;
    
    if (!directOriginalMethod) {
      bcopy(inheritedOriginalMethod, hoisted_method, sizeof(struct objc_method));
      directOriginalMethod = hoisted_method++;
    }
    if (!directAlternateMethod) {
      bcopy(inheritedAlternateMethod, hoisted_method, sizeof(struct objc_method));
      directAlternateMethod = hoisted_method;
    }
    class_addMethods(self, hoisted_method_list);
  }
  
  //  Swizzle.
  IMP temp = directOriginalMethod->method_imp;
  directOriginalMethod->method_imp = directAlternateMethod->method_imp;
  directAlternateMethod->method_imp = temp;
  
  return YES;
#endif
}

+ (BOOL)jr_swizzleClassMethod:(SEL)origSel_ withClassMethod:(SEL)altSel_ error:(NSError**)error_ {
  assert(0);
  return NO;
}

@end
