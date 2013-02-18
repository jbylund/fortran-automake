# This makefile is largely self writing, you only have to put a file in src or src/academic
# and the makefile will determine any dependencies and compile in the correct order
EXEC_NAME := $(shell find $(SRC_DIR) -type f -name "*.F" -exec grep -Eil "^ {6,}program" {} \; | xargs -n 1 -I{} basename {} .F )
AGBNP_INC = -Iagbnp
linker = compiler
src_academic_dir = src_academic
src_agbnp = agbnp
src_dir = src
src_molsurf = molsurf

# The following line fixes a GNU make issue in which Fortran .mod files are misinterpretted as Modula-2 files.
%.o : %.mod

ccompiler := $(shell which gcc)
compiler  := $(shell which gfortran)
obj_dir   := .obj_gfortran
mod_dir   := .mod_gfortran
mod_ext   := _mod.o
flags     := -c -ffixed-line-length-132 -fdefault-double-8 -fdefault-real-8 -I$(obj_dir) -J$(mod_dir) -fno-range-check $(COMPILER_FLAGS)
cflags    := -c -finline-functions -O2
Dflags    := $(PREPROCESSOR_FLAGS) -DDYNAMIC -DACADEMIC
lflags    := -L$(obj_dir) -I$(obj_dir) $(LINKER_FLAGS)
ifneq (,$(findstring -g,$(COMPILER_FLAGS)))
  flags := $(flags) -fbacktrace
endif

ifeq ($(linker),compiler)
  linker := $(compiler)
endif

# find all source files
all_source_files = $(shell find src -type f -name "*.F" | sort)

# search for source files in src
objects := $(shell find src -maxdepth 1 -name "*.F" -exec grep -EiL "^ {6,}module" {} \; | xargs -n 1 -I{} basename {} .F | sort)
objects := $(addsuffix .o, $(objects))
objects := $(addprefix $(obj_dir)/, $(objects))

# search for fortran module files
module_objects := $(shell find src -maxdepth 1 -name "*.F" -exec grep -Eil "^ {6,}module" {} \; | xargs -n 1 -I{} basename {} _mod.F | sort)
module_objects := $(addsuffix $(mod_ext),$(module_objects))
module_objects := $(addprefix $(mod_dir)/, $(module_objects))

# store the compiler version, so it's ready to go later, there's still a possibility that other commands will execute before the echo's finish
ifneq (,$(compiler))
compiler_version := $(shell $(compiler) --version | grep -E "[A-Za-z0-9]")
endif

# Directories that we'll need
ifneq (,$(obj_dir))
$(shell [ -d "$(obj_dir)" ] || mkdir -p $(obj_dir))
$(shell [ -d "$(mod_dir)" ] || mkdir -p $(mod_dir))
endif

all : .depends $(EXEC_NAME)
	@:

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
	@./scripts/make_depends $(Dflags) $(all_source_files) > .depends

include .depends

# To make final executable
$(EXEC_NAME) : $(module_objects) $(objects) 
	@echo "Linking..."
	$(linker) -o $(EXEC_NAME) $(objects) $(module_objects) $(lflags)

.PHONY : clean  

# majority of non-module source files
$(obj_dir)/%.o : $(src_dir)/%.F
	echo "using non-module"
	$(compiler) -o $@ $(flags) $(Dflags) $<

# modules
$(mod_dir)/%$(mod_ext) : $(src_dir)/%_mod.F
	echo "using module"
	$(compiler) -o $@ $(flags) $(Dflags) $<

# remainder, if there are any remaining, assume they depend on all modules
$(obj_dir)/%.o: $(src_dir)/%.F $(module_objects)
	echo "using remainder"
	$(compiler) -o $@ $(flags) $(Dflags) $<

