/*
 Arq7 type definitions for arq_restore.
 These avoid conflicts with existing arq_restore Arq5 types.
*/

#ifndef Arq7Types_h
#define Arq7Types_h

typedef enum {
    kArq7CompressionTypeNone = 0,
    kArq7CompressionTypeGzip = 1,
    kArq7CompressionTypeLZ4 = 2
} Arq7CompressionType;

enum {
    kArq7ComputerOSTypeMac = 1,
    kArq7ComputerOSTypeWindows = 2
};
typedef uint32_t Arq7ComputerOSType;

#endif /* Arq7Types_h */
