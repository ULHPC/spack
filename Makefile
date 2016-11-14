####################################################################################
# Makefile (configuration file for GNU make - see http://www.gnu.org/software/make/)
# Time-stamp: <Jeu 2015-04-02 10:28 svarrette>
#     __  __       _         __ _ _
#    |  \/  | __ _| | _____ / _(_) | ___
#    | |\/| |/ _` | |/ / _ \ |_| | |/ _ \
#    | |  | | (_| |   <  __/  _| | |  __/
#    |_|  |_|\__,_|_|\_\___|_| |_|_|\___|
#
# Copyright (c) 2012 Sebastien Varrette <Sebastien.Varrette@uni.lu>
# .             http://varrette.gforge.uni.lu
#
####################################################################################
#
############################## Variables Declarations ##############################
SHELL = /bin/bash

UNAME = $(shell uname)

# Some directories
SUPER_DIR   = $(shell basename `pwd`)

# Git stuff management
HAS_GITFLOW      = $(shell git flow version 2>/dev/null || [ $$? -eq 0 ])
LAST_TAG_COMMIT = $(shell git rev-list --tags --max-count=1)
LAST_TAG = $(shell git describe --tags $(LAST_TAG_COMMIT) )
TAG_PREFIX = "v"
# GITFLOW_BR_MASTER  = $(shell git config --get gitflow.branch.master)
# GITFLOW_BR_DEVELOP = $(shell git config --get gitflow.branch.develop)
GITFLOW_BR_MASTER=master
GITFLOW_BR_DEVELOP=unilu
# LLNL upstream git-flow develop
GITFLOW_BR_DEVELOP_UPSTREAM=develop

CURRENT_BRANCH = $(shell git rev-parse --abbrev-ref HEAD)
GIT_BRANCHES   = $(shell git for-each-ref --format='%(refname:short)' refs/heads/ | xargs echo)
GIT_REMOTES    = $(shell git remote | xargs echo )
GIT_DIRTY      = $(shell git diff --shortstat 2> /dev/null | tail -n1 )
# Git subtrees repositories
# Format: '<url>[|<branch>]' - don't forget the quotes. if branch is ignored, 'master' is used
#GIT_SUBTREE_REPOS = 'https://github.com/ULHPC/easybuild-framework.git|develop'  \
					 'https://github.com/hpcugent/easybuild-wiki.git'
GITSTATS     = ./.submodules/gitstats/gitstats
GITSTATS_DIR = gitstats

VERSION    = $(shell  git describe --tags $(LAST_TAG_COMMIT) | sed "s/^$(TAG_PREFIX)//")
MAJOR      = $(shell echo $(VERSION) | sed "s/^\([0-9]*\).*/\1/")
MINOR      = $(shell echo $(VERSION) | sed "s/[0-9]*\.\([0-9]*\).*/\1/")
PATCH      = $(shell echo $(VERSION) | sed "s/[0-9]*\.[0-9]*\.\([0-9]*\).*/\1/")
# total number of commits
BUILD      = $(shell git log --oneline | wc -l | sed -e "s/[ \t]*//g")
#REVISION   = $(shell git rev-list $(LAST_TAG).. --count)
#ROOTDIR    = $(shell git rev-parse --show-toplevel)
NEXT_MAJOR_VERSION = $(shell expr $(MAJOR) + 1).0.0
NEXT_MINOR_VERSION = $(MAJOR).$(shell expr $(MINOR) + 1).0
NEXT_PATCH_VERSION = $(MAJOR).$(MINOR).$(shell expr $(PATCH) + 1)

# Default targets
TARGETS =

# Local configuration - Kept for backward compatibity reason
LOCAL_MAKEFILE = .Makefile.local

# Makefile custom hooks
MAKEFILE_BEFORE = .Makefile.before
MAKEFILE_AFTER  = .Makefile.after

### Main variables
.PHONY: all archive clean fetch help release setup start_bump_major start_bump_minor start_bump_patch subtree_setup subtree_up subtree_diff test upgrade versioninfo

############################### Now starting rules ################################
# Load local settings, if existing (to override variable eventually)
ifneq (,$(wildcard $(LOCAL_MAKEFILE)))
include $(LOCAL_MAKEFILE)
endif
ifneq (,$(wildcard $(MAKEFILE_BEFORE)))
include $(MAKEFILE_BEFORE)
endif

# Required rule : what's to be done each time
all: $(TARGETS)

# Test values of variables - for debug purposes
info:
	@echo "--- Compilation commands --- "
	@echo "HAS_GITFLOW      -> '$(HAS_GITFLOW)'"
	@echo "--- Directories --- "
	@echo "SUPER_DIR    -> '$(SUPER_DIR)'"
	@echo "--- Git stuff ---"
	@echo "GITFLOW            -> '$(GITFLOW)'"
	@echo "GITFLOW_BR_MASTER  -> '$(GITFLOW_BR_MASTER)'"
	@echo "GITFLOW_BR_DEVELOP -> '$(GITFLOW_BR_DEVELOP)'"
	@echo "GITFLOW_BR_DEVELOP_UPSTREAM -> '$(GITFLOW_BR_DEVELOP_UPSTREAM)'"
	@echo "CURRENT_BRANCH     -> '$(CURRENT_BRANCH)'"
	@echo "GIT_BRANCHES       -> '$(GIT_BRANCHES)'"
	@echo "GIT_REMOTES        -> '$(GIT_REMOTES)'"
	@echo "GIT_DIRTY          -> '$(GIT_DIRTY)'"
	@echo "GIT_SUBTREE_REPOS  -> '$(GIT_SUBTREE_REPOS)'"
	@echo ""
	@echo "Consider running 'make versioninfo' to get info on git versionning variables"

############################### Archiving ################################
archive: clean
	tar -C ../ -cvzf ../$(SUPER_DIR)-$(VERSION).tar.gz --exclude ".svn" --exclude ".git"  --exclude "*~" --exclude ".DS_Store" $(SUPER_DIR)/

############################### Git Bootstrapping rules ################################
setup:
	git fetch origin
	if [[ "$(GIT_BRANCHES)" != *"$(GITFLOW_BR_MASTER)"* ]]; then \
		git branch --track $(GITFLOW_BR_MASTER) origin/$(GITFLOW_BR_MASTER); \
	fi
	git config gitflow.branch.master     $(GITFLOW_BR_MASTER)
	git config gitflow.branch.develop    $(GITFLOW_BR_DEVELOP)
	git config gitflow.prefix.feature    feature/
	git config gitflow.prefix.release    release/
	git config gitflow.prefix.hotfix     hotfix/
	git config gitflow.prefix.support    support/
	git config gitflow.prefix.versiontag $(TAG_PREFIX)
	$(MAKE) update
	$(if $(GIT_SUBTREE_REPOS), $(MAKE) subtree_setup)
	if [[ "$(GIT_REMOTES)" != *"upstream"* ]]; then \
		git remote add -f upstream https://github.com/LLNL/spack; \
	fi

fetch:
	git fetch --all -v

# See https://help.github.com/articles/syncing-a-fork/
sync:
	@echo "=> synchronize this fork with the upstream (LLNL) remote"
	$(MAKE) fetch
	git checkout $(GITFLOW_BR_MASTER)
	git merge upstream/$(GITFLOW_BR_MASTER)
	git checkout $(GITFLOW_BR_DEVELOP_UPSTREAM)
	git merge upstream/$(GITFLOW_BR_DEVELOP_UPSTREAM)
  git checkout $(GITFLOW_BR_DEVELOP)

versioninfo:
	@echo "Current version: $(VERSION)"
	@echo "Last tag: $(LAST_TAG)"
	@echo "$(shell git rev-list $(LAST_TAG).. --count) commit(s) since last tag"
	@echo "Build: $(BUILD) (total number of commits)"
	@echo "next major version: $(NEXT_MAJOR_VERSION)"
	@echo "next minor version: $(NEXT_MINOR_VERSION)"
	@echo "next patch version: $(NEXT_PATCH_VERSION)"


### Git submodule management: pull and upgrade to the latest version
update:
	git pull origin
	git submodule init
	git submodule update

upgrade: update
	git submodule foreach 'git fetch origin; git checkout $$(git rev-parse --abbrev-ref HEAD); git reset --hard origin/$$(git rev-parse --abbrev-ref HEAD); git submodule update --recursive; git clean -dfx'
	@for submoddir in $(shell git submodule status | awk '{ print $$2 }' | xargs echo); do \
		git commit -s -m "Upgrading Git submodule '$$submoddir' to the latest version" $$submoddir || true;\
	done

# Clean option
clean:
	@echo nothing to be cleaned for the moment


# print help message
help :
	@echo '+----------------------------------------------------------------------+'
	@echo '|                        Main Available Commands                       |'
	@echo '+----------------------------------------------------------------------+'
	@echo '| make setup: Initiate git-flow for your local copy of the repository  |'
	@echo '| make sync:  synchronize this fork with the (LLNL) upstream           |'
	@echo '+----------------------------------------------------------------------+'

ifneq (,$(wildcard $(MAKEFILE_AFTER)))
include $(MAKEFILE_AFTER)
endif
