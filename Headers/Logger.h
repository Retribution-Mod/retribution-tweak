#import <Foundation/Foundation.h>

#define LOG_PREFIX @"[Retribution]"
#define RetributionLog(fmt, ...) NSLog((LOG_PREFIX @" " fmt), ##__VA_ARGS__)
