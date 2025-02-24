# Etiquette

An Oberon tool to tag files by using file system extended attributes.

This video presents how it works: https://toobnix.org/w/43z3xJSwZRU2iBNZPZkChv

# Why

Did you try to organize your film/book/music library? Or your own photos?
By year? By camera? by place?

How do you classify the films: By director? By Country? By language? By actors? By scriptwriter?

With Etiquette tool you can tag one file as director: Larry David, and other file as: Actor: Larry David.

Then you can list the files where LD is an actor, and list files where LD is a director. Same with languages, countries of production and any other taxonomy you want.

# How it works

It stores the data in the modern Unix File System Extended Attributes.
Other solutions I found were storing tags in the separate db. That means each time you move the file, the db record has to be changed.
Then you have to copy/move files with some specific ui or cmdline programs, in order to preserve the tags.

With this solution you just use your _any_ file manager, `cp`, `mv` commands, etc. The tags will follow.

# ui

For a regular end user, I am writing a UI program, with which one can organize everything: clothes, books, films, whatever.

# Problems

It's not possible to query Unix File System for xattrs. We need to search in the current directory (recoursively? should i add it?) for the files that have specified tag.

My research shows that Haiku file system has this option.

# Future

Ports to other Unix systems are in process. just xattr.Mod for FreeBSD, OpenBSD, NetBSD, Illumos, MacOS needs to be written. You are welcome to contribute!
I think it'll also work on Windows, since NTFS has xattrs.

Oberon has this cool feature: you can have files like `xattrsLinux.Mod` and `xattrsFreeBSD.Mod` but the module name inside the module is mentioned as `MODULE xattrs;` then the module will compile to `xattrs.o` which we'll be able to later link to our resulting program.

## Options
```
options:

-a, --add = VALUE
               add a tag
-f, --file = VALUE
               <no description>
-d, --delete = VALUE
               <no description>
-C, --clear
               <no description>
-l, --list
               <no description>
-F, --filter = VALUE
               filter files by tag
-h, --help
               show this help
-p, --prefix = VALUE
               specify xattr namespace
-v, --verbose
               verbose output
```

Inspired by Wizzup's [python tag tool](http://hetgrotebos.org/wiki/neversearch).
