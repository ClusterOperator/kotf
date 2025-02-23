GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
BASEPATH := $(shell pwd)
BUILDDIR=$(BASEPATH)/dist

KOTF_SRC=$(BASEPATH)/cmd
KOTF_SERVER_NAME=kotf-server

BIN_DIR=usr/local/bin
CONFIG_DIR=etc/kotf
BASE_DIR=var/kotf
RESOURCE_DIR=resource
GOPROXY="https://goproxy.cn,direct"

build_server_linux:
	GOOS=linux GOARCH=$(GOARCH)  $(GOBUILD) -o $(BUILDDIR)/$(BIN_DIR)/$(KOTF_SERVER_NAME) $(KOTF_SRC)/server/*.go
	mkdir -p $(BUILDDIR)/$(CONFIG_DIR) && cp -r  $(BASEPATH)/conf/* $(BUILDDIR)/$(CONFIG_DIR)
	mkdir -p $(BUILDDIR)/${BASE_DIR}/$(RESOURCE_DIR) && cp -r  $(BASEPATH)/resource/* $(BUILDDIR)/${BASE_DIR}/$(RESOURCE_DIR)

clean:
	$(GOCLEAN)
	rm -fr $(BUILDDIR)

docker:
	@echo "build docker images"
	docker build -t clusteroperator/kotf:master --build-arg GOPROXY=$(GOPROXY) --build-arg GOARCH=$(GOARCH) .
