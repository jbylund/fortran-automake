fortran-automake
================
This project aims to simplify the build process of fortran based projects.
Significantly it aims to determine dependencies between fortran module 
files & explicitly pass these dependencies to make. 
This allows make to make full use of multiple threads in compilation.
Originally written by Joseph Bylund, 2011.
Modified for use in the protein local optimization program.
Closed source for now, looking into license options.
