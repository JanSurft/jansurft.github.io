BASEDIR=$(CURDIR)
TASKDIR=$(CURDIR)/tasks
STATICS=$(CURDIR)/statics

.PHONY: deploy-local jekyll-build all

all: deploy-local

deploy-local: jekyll-build
	$(TASKDIR)/deploy-local	

jekyll-build:
	JEKYLL_ENV=production jekyll build
