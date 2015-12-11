PESutils
========

[![Build Status](https://travis-ci.org/CounterPillow/pesutils.svg?branch=master)](https://travis-ci.org/CounterPillow/pesutils)

Introduction
------------

PESutils is a collection of code which allows to manipulate and inspect the game
files of Konami's Pro Evolution Soccer game series. Currently, the software is 
in the early stages of development.

Installation
------------

### Building from Source

You will need:

 * [A D compiler such as DMD](http://dlang.org/download.html)
 
 * [Dub, a D package management and build system](http://code.dlang.org/download)
 
To compile, run the following command:

```
dub build pesutils:wesys
```

### Pre-built Windows binaries

Manually built Windows 32-bit binaries compiled with DMD are available.

**Download:** http://rigged.cunt.blue/pesutils/builds/win32/

Tools
-----

### pesutils_wesys

Allows extracting and compressing WESYS compressed files.

**Usage:**

```
pesutils_wesys --action compress|decompress [--prefix prefix] [--force] [--stdout] [--level level] FILES...

```

The default prefix for newly created compressed files is `wesys_`, the default
prefix for newly created uncompressed files is `unwesys_`. You may set this 
yourself by using `--prefix` (or `-p`).

The option `--stdout` (or `-o`) forces the program to write to stdout instead of creating
files.

The program will not overwrite files, unless `--force` (or `-f`) is specified. Otherwise, 
it will abort as soon as it encounters an already existing file.

The user may set the compression level using `--level` (or `-l`) to a value between 0 and 9, where 0 is the lowest amount of compression and 9 is the highest amount of compression.

License
-------

Unless otherwise stated, all material in this repository is licensed under the 
terms and conditions of the zlib license. The full license text is available in 
the LICENSE file.
