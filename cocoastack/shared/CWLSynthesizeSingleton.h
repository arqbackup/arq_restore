//
//  CWLSynthesizeSingleton.h
//  CocoaWithLove
//
//  Created by Matt Gallagher on 2011/08/23.
//  Copyright (c) 2011 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import <objc/runtime.h>

#define CWL_DECLARE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(classname, accessorMethodName) \
+ (classname *)accessorMethodName;

#if __has_feature(objc_arc)
	#define CWL_SYNTHESIZE_SINGLETON_RETAIN_METHODS
#else
	#define CWL_SYNTHESIZE_SINGLETON_RETAIN_METHODS \
	- (id)retain \
	{ \
		return self; \
	} \
	 \
	- (NSUInteger)retainCount \
	{ \
		return NSUIntegerMax; \
	} \
	 \
	- (oneway void)release \
	{ \
	} \
	 \
	- (id)autorelease \
	{ \
		return self; \
	}
#endif

#define CWL_SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(classname, accessorMethodName) \
 \
static classname *accessorMethodName##Instance = nil; \
 \
+ (classname *)accessorMethodName \
{ \
	@synchronized(self) \
	{ \
		if (accessorMethodName##Instance == nil) \
		{ \
			accessorMethodName##Instance = [super allocWithZone:NULL]; \
			accessorMethodName##Instance = [accessorMethodName##Instance init]; \
			method_exchangeImplementations(\
				class_getClassMethod([accessorMethodName##Instance class], @selector(accessorMethodName)),\
				class_getClassMethod([accessorMethodName##Instance class], @selector(cwl_lockless_##accessorMethodName)));\
			method_exchangeImplementations(\
				class_getInstanceMethod([accessorMethodName##Instance class], @selector(init)),\
				class_getInstanceMethod([accessorMethodName##Instance class], @selector(cwl_onlyInitOnce)));\
		} \
	} \
	 \
	return accessorMethodName##Instance; \
} \
 \
+ (classname *)cwl_lockless_##accessorMethodName \
{ \
	return accessorMethodName##Instance; \
} \
\
+ (id)allocWithZone:(NSZone *)zone \
{ \
	return [self accessorMethodName]; \
} \
 \
- (id)copyWithZone:(NSZone *)zone \
{ \
	return self; \
} \
- (id)cwl_onlyInitOnce \
{ \
	return self;\
} \
 \
CWL_SYNTHESIZE_SINGLETON_RETAIN_METHODS

#define CWL_DECLARE_SINGLETON_FOR_CLASS(classname) CWL_DECLARE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(classname, shared##classname)
#define CWL_SYNTHESIZE_SINGLETON_FOR_CLASS(classname) CWL_SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(classname, shared##classname)
