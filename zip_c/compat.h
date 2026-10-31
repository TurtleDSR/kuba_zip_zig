#ifndef ZIG_COMPAT_H
#define ZIG_COMPAT_H

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

//map legacy 64-bit structs to modern standard types on glibc targets
#define stat64 stat
#define lstat64 lstat
#define fstat64 fstat

#endif