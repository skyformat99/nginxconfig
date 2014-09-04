# file:   Makefile used for building and running the project.
# author: Travis Gockel <travis@gockelhut.com>
#
# Building the library is as easy as:
# 
#  $> make
#
# This will create library files in the build directory: libnginxconfig.a and libnginxconfig.so, which you can link to
# whatever project you please.
#
# Most configuration is overridable by appending arguments after make. For example, to use the C++14 standard instead
# of the default, you simply say:
#
#  $> make CXX_STANDARD="--std=c++14"
#
# If typing these extra arguments is inconvenient, you can set up defaults in either ./Makefile.user or in
# ~/.config/nginxconfig/Makefile.ex, which will be included if either exists (or both). This is a full-featured
# extension to the Makefile, so feel free to add custom targets or whatever else you might need for your build. The
# locations for this can also be overridden on the command line with MAKEFILE_EXTENSIONS.
#
# Having trouble building? Is the pretty echo CXX bothering you? It might be helpful to see the actual command line
# getting passed to your compiler/archiver/linker/whatever.
#
#  $> make VERBOSE=1
#
# For development, you probably want to run the unit tests. To run all of them:
#
#  $> make test
#
# To pass arguments to the program running the tests, simply add ARGS (for example, only run the parse tests):
#
#  $> make test ARGS='parse'
#
# 
# Copyright 2014 by Travis Gockel
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the License.

# Support extending the contents of the Makefile with custom configurations
MAKEFILE_EXTENSIONS ?= Makefile.user ${HOME}/.config/nginxconfig/Makefile.ex
define MAKEFILE_EXTENSION_TEMPLATE
  ifneq ($$(wildcard $1),)
    -include $1
  endif
endef
$(foreach extension,$(MAKEFILE_EXTENSIONS),$(eval $(call MAKEFILE_EXTENSION_TEMPLATE,$(extension))))

NGINXCONFIG_VERSION ?= 0.1.1

################################################################################
# Configuration                                                                #
################################################################################

# def: USE_BOOST_REGEX
# Controls the variable NGINXCONFIG_USE_BOOST_REGEX (see C++ documentation).
USE_BOOST_REGEX ?= 0

# def: BOOST_REGEX_LIB
# The library flag used to link to if USE_BOOST_REGEX is 1.
BOOST_REGEX_LIB ?= -lboost_regex

# def: BOOST_SYSTEM_LIB
# The library flag used to link to if USE_BOOST_REGEX is 1.
BOOST_SYSTEM_LIB ?= -lboost_system

# def: VERSION_STYLE
# For the strongly-versioned shared objects, how should the version be styled? There are a few options...
# 
#  - standard
#    lib$(NAME).so-$(VERSION)
#  - internal
#    lib$(NAME)-$(VERSION).so
#  - custom
#    Define a template for VERSIONED_SO yourself.
VERSION_STYLE ?= standard

ifeq ($(VERSION_STYLE),standard)
  VERSIONED_SO = lib$(1).so-$(2)
else
 ifeq ($(VERSION_STYLE),internal)
   VERSIONED_SO = lib$(1)-$(2).so
 else
  ifeq ($(VERSION_STYLE),custom)
   ifndef VERSIONED_SO
     $(error VERSION_STYLE set to custom but VERSIONED_SO is not defined)
   endif
  else
   $(error Invalid VERSION_STYLE "$(VERSION_STYLE)")
  endif
 endif
endif

################################################################################
# Build Paths                                                                  #
################################################################################

ifeq ($(.DEFAULT_GOAL),)
  .DEFAULT_GOAL := nginxconfig
endif

CONF        ?= release
HEADER_DIR  ?= include
SRC_DIR     ?= src
BUILD_ROOT  ?= build
BUILD_DIR   ?= $(BUILD_ROOT)/$(CONF)
OBJ_DIR     ?= $(BUILD_DIR)/obj
DEP_DIR     ?= $(BUILD_DIR)/dep
LIB_DIR     ?= $(BUILD_DIR)/lib
BIN_DIR     ?= $(BUILD_DIR)/bin
INSTALL_DIR ?= /usr

ifeq ($(VERBOSE),)
  Q  := @
  QQ := @
else
 ifeq ($(VERBOSE),1)
  Q  :=
  QQ := @
 else
  Q  := 
  QQ := 
 endif
endif

HEADER_FILES    = $(shell find $(HEADER_DIR) -type f -name "*.hpp")
CXX_FILES       = $(shell find $(SRC_DIR)    -type f -name "*.cpp")
OBJ_FILES       = $(patsubst $(SRC_DIR)/%,$(OBJ_DIR)/%.o,$(CXX_FILES))
DEP_FILES       = $(shell find $(DEP_DIR) -type f -name "*.dep" 2>/dev/null)

.PRECIOUS: $(OBJ_FILES)

$(foreach dep,$(DEP_FILES),$(eval -include $(dep)))

LIBRARIES = $(patsubst $(SRC_DIR)/%,%,$(wildcard $(SRC_DIR)/*))
TESTS     = $(filter %-tests,$(LIBRARIES))

################################################################################
# Compiler Settings                                                            #
################################################################################

CXX            = $(CXX_COMPILER) $(CXX_FLAGS) $(CXX_INCLUDES) $(CXX_DEFINES)
CXX_COMPILER  ?= c++
CXX_FLAGS     ?= $(CXX_STANDARD) -c $(CXX_WARNINGS) -ggdb -fPIC $(CXX_FLAGS_$(CONF))
CXX_INCLUDES  ?= -I$(SRC_DIR) -I$(HEADER_DIR)
CXX_STANDARD  ?= --std=c++11
CXX_DEFINES   ?= -DNGINXCONFIG_USE_BOOST_REGEX=$(USE_BOOST_REGEX)
CXX_WARNINGS  ?= -Werror -Wall -Wextra
LD             = $(CXX_COMPILER) $(LD_PATHS) $(LD_FLAGS)
LD_FLAGS      ?= 
LD_PATHS      ?= 
LD_LIBRARIES  ?= 
SO             = $(CXX_COMPILER) $(SO_PATHS) $(SO_FLAGS)
SO_FLAGS      ?= 
SO_PATHS      ?= 
SO_LIBRARIES  ?= 
INSTALL        = install $(INSTALL_FLAGS)
INSTALL_FLAGS ?= 

################################################################################
# Libraries                                                                    #
################################################################################

define LIBRARY_TEMPLATE
  $1_SYMBOL        = $$(subst -,_,$$(shell echo $1 | tr '[:lower:]' '[:upper:]'))
  $1_OBJS          = $$(filter $$(OBJ_DIR)/$1/%,$$(OBJ_FILES))
  $1_LIB_FILES     = $$(patsubst %,$$(LIB_DIR)/lib%.so,$$($1_LIBS))
  $1_LD_LIBRARIES  = $$(patsubst %,-l%,$$($1_LIBS)) $$(LD_LIBRARIES)
  $1_HEADER_FILES  = $$(filter $$(HEADER_DIR)/$1/%,$$(HEADER_FILES))

  $1 : $$(LIB_DIR)/lib$1.a $$(LIB_DIR)/$(call VERSIONED_SO,$1,$$(NGINXCONFIG_VERSION)) $$(LIB_DIR)/lib$1.so
endef

$(foreach lib,$(LIBRARIES),$(eval $(call LIBRARY_TEMPLATE,$(lib))))

CXX_FLAGS_release = -O3

nginxconfig-tests_LIBS = nginxconfig

ifeq ($(USE_BOOST_REGEX),1)
  nginxconfig-tests_LD_LIBRARIES += $(BOOST_REGEX_LIB) $(BOOST_SYSTEM_LIB)
endif

################################################################################
# Build Recipes                                                                #
################################################################################

$(OBJ_DIR)/%.cpp.o : $(SRC_DIR)/%.cpp
	$(QQ)echo " CXX   $*.cpp"
	$(QQ)mkdir -p $(@D)
	$(QQ)mkdir -p $(dir $(patsubst $(SRC_DIR)/%,$(DEP_DIR)/%,$<))
	$Q$(CXX) $< -o $@ -D$($(shell echo $* | grep -Po '^[^/]+')_SYMBOL)_COMPILING=1                                 \
	        -MF $(patsubst $(SRC_DIR)/%.cpp,$(DEP_DIR)/%.cpp.dep,$<) -MMD

.SECONDEXPANSION:
$(LIB_DIR)/lib%.a : $$($$*_OBJS)
	$(QQ)echo " AR    lib$*.a"
	$(QQ)mkdir -p $(@D)
	$Q$(AR) cr $@ $^

.SECONDEXPANSION:
$(LIB_DIR)/$(call VERSIONED_SO,%,$(NGINXCONFIG_VERSION)) : $$($$*_OBJS)
	$(QQ)echo " SO    $(call VERSIONED_SO,$*,$(NGINXCONFIG_VERSION))"
	$(QQ)mkdir -p $(@D)
	$Q$(SO) -shared -Wl,-soname,$(call VERSIONED_SO,$*,$(NGINXCONFIG_VERSION)) $^ -o $@

$(LIB_DIR)/lib%.so : $(LIB_DIR)/$(call VERSIONED_SO,%,$(NGINXCONFIG_VERSION))
	$(QQ)echo " LN    $< -> $@"
	$(QQ)rm -f $@
	$Qln -s $(call VERSIONED_SO,$*,$(NGINXCONFIG_VERSION)) $@

define TEST_TEMPLATE
  $$(BIN_DIR)/$1 : $$($1_OBJS) $$($1_LIB_FILES)
	$$(QQ)echo " LD    $1"
	$$(QQ)mkdir -p $$(@D)
	$$Q$$(LD) $$($1_OBJS) -L $$(LIB_DIR) $$($1_LD_LIBRARIES) -Wl,--rpath,$$(LIB_DIR) -o $$@

  $1 : $$(BIN_DIR)/$1
	$$(QQ)echo " TEST  $1 $$(ARGS)"
	$$Q./$$< $$(ARGS)
endef

$(foreach test,$(TESTS),$(eval $(call TEST_TEMPLATE,$(test))))

define INSTALL_TEMPLATE
  install_$(1) : $$(LIB_DIR)/$$(call VERSIONED_SO,$1,$$(NGINXCONFIG_VERSION)) $$(LIB_DIR)/lib$1.so
	$$(QQ)echo " INSTL $1 -> $$(INSTALL_DIR)"
	$$(QQ)mkdir -p $$(INSTALL_DIR)/lib
	$$Q$(INSTALL) $$(LIB_DIR)/$$(call VERSIONED_SO,$1,$$(NGINXCONFIG_VERSION)) $$(LIB_DIR)/lib$1.so $$(INSTALL_DIR)/lib
	$$Q$(INSTALL) --directory $$(HEADER_DIR)/$1 $$(INSTALL_DIR)/include/$1
	$$Q$(INSTALL) $$($(1)_HEADER_FILES) $$(INSTALL_DIR)/include/$1
endef

$(foreach lib,$(LIBRARIES),$(eval $(call INSTALL_TEMPLATE,$(lib))))

################################################################################
# Convenience                                                                  #
################################################################################

test : $(TESTS)

clean :
	$(QQ)echo " RM    $(BUILD_ROOT)"
	$Qrm -rf $(BUILD_ROOT)

clean-src :
	$(QQ)echo " RM    $(SRC_DIR)/**/*~"
	$Qfind $(SRC_DIR)     -name '*~' -delete
	$Qfind $(INCLUDE_DIR) -name '*~' -delete

install : install_nginxconfig
