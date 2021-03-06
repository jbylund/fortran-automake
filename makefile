# This makefile is largely self writing, you only have to put a file in $(SRC_DIR)
# and the makefile will determine any dependencies and compile in the correct order
SRC_DIR   := src
ccompiler := $(shell which gcc)
cflags    := -c -finline-functions -O2
compiler  := $(shell which gfortran)
Dflags    := $(PREPROCESSOR_FLAGS)
linker    := compiler
mod_dir   := .mod_gfortran
obj_dir   := .obj_gfortran

# from here down things should be automatically determined
EXEC_NAME := $(shell [ -d "$(SRC_DIR)" ] && find $(SRC_DIR) -type f -name "*.F" -exec grep -Eil "^ {6,}program" {} \; | xargs -n 1 -I{} basename {} .F )
flags     := -c -ffixed-line-length-132 -fdefault-double-8 -fdefault-real-8 -I$(obj_dir) -J$(mod_dir) -fno-range-check $(COMPILER_FLAGS)
lflags    := -L$(obj_dir) -I$(obj_dir) $(LINKER_FLAGS)
mod_ext   := _mod.o

# The following line fixes a GNU make issue in which Fortran .mod files are misinterpretted as Modula-2 files.
%.o : %.mod

# if -g flag is in compiler flags then add the backtrace flag
ifneq (,$(findstring -g,$(COMPILER_FLAGS)))
  flags := $(flags) -fbacktrace
endif

# if the linker is set to "compiler" set it to the value of $(compiler)
ifeq ($(linker),compiler)
  linker := $(compiler)
endif

# find all source files
all_source_files := $(shell [ -d "$(SRC_DIR)" ] && find $(SRC_DIR) -type f -name "*.F" | sort)

# search for source files in src
objects := $(shell [ -d "$(SRC_DIR)" ] && find $(SRC_DIR) -maxdepth 1 -name "*.F" -exec grep -EiL "^ {6,}module" {} \; | xargs -n 1 -I{} basename {} .F | sort)
objects := $(addsuffix .o, $(objects))
objects := $(addprefix $(obj_dir)/, $(objects))

# search for fortran module files
module_objects := $(shell [ -d "$(SRC_DIR)" ] && find $(SRC_DIR) -maxdepth 1 -name "*.F" -exec grep -Eil "^ {6,}module" {} \; | xargs -n 1 -I{} basename {} _mod.F | sort)
module_objects := $(addsuffix $(mod_ext),$(module_objects))
module_objects := $(addprefix $(mod_dir)/, $(module_objects))

# store the compiler version, so it's ready to go later
# only include the lines with contents
ifneq (,$(compiler))
compiler_version := $(shell $(compiler) --version | grep -E "[A-Za-z0-9]")
endif


# Directories that we'll need
ifneq (,$(obj_dir))
$(shell [ -d "$(obj_dir)" ] || mkdir -p $(obj_dir))
$(shell [ -d "$(mod_dir)" ] || mkdir -p $(mod_dir))
endif

ifeq (,$(EXEC_NAME))
all : .depends $(EXEC_NAME)
	@echo "Found nothing to build."
else
all : .depends $(EXEC_NAME)
	@:
endif

# Clean
# finds all .o objects, and then removes any empty directories
# could actually delete directories which did not contain objects
clean :
	@echo "Removing objects."
	@-find . -type f -name "*.mod" -exec /bin/rm {} \;
	@-find . -type f -name "*.o" -exec /bin/rm {} \;
	@echo "Removing empty directories."
	@-find -depth -type d -empty -exec /bin/rmdir {} \;
	@/bin/rm -f .depends


# Automate finding of dependencies
.depends : $(all_source_files) ./scripts/make_depends
	@ ./scripts/make_depends $(Dflags) $(all_source_files) > .depends

include .depends

# To make final executable
$(EXEC_NAME) : $(module_objects) $(objects) 
	@echo "Linking..."
	$(linker) -o $(EXEC_NAME) $(objects) $(module_objects) $(lflags)

.PHONY : clean  

# majority of non-module source files
$(obj_dir)/%.o : $(SRC_DIR)/%.F
	echo "using non-module"
	$(compiler) -o $@ $(flags) $(Dflags) $<

# modules
$(mod_dir)/%$(mod_ext) : $(SRC_DIR)/%_mod.F
	echo "using module"
	$(compiler) -o $@ $(flags) $(Dflags) $<

# remainder, if there are any remaining, assume they depend on all modules
$(obj_dir)/%.o: $(SRC_DIR)/%.F $(module_objects)
	echo "using remainder"
	$(compiler) -o $@ $(flags) $(Dflags) $<

