KERNELRELEASE ?= $(shell uname -r)
KSRC ?= /lib/modules/$(KERNELRELEASE)/build

CONFIG_CLK_RK3308 ?= rockchip
CONFIG_CLK_RK3328 ?= rockchip
CONFIG_CLK_RK3399 ?= rockchip
CONFIG_CLK_RK3528 ?= rockchip
CONFIG_CLK_RK3568 ?= rockchip
CONFIG_CLK_RK3576 ?= rockchip
CONFIG_CLK_RK3588 ?= rockchip
CONFIG_ARCH_MESON ?= amlogic
CONFIG_ARCH_SUNXI ?= allwinner
include $(wildcard arch/arm64/boot/dts/*/overlays/Makefile)

DTBO-ALLWINNER	:=	$(addprefix arch/arm64/boot/dts/allwinner/overlays/,$(dtb-allwinner))
DTBO-AMLOGIC	:=	$(addprefix arch/arm64/boot/dts/amlogic/overlays/,$(dtb-amlogic))
DTBO-ROCKCHIP	:=	$(addprefix arch/arm64/boot/dts/rockchip/overlays/,$(dtb-rockchip))
DTBO		:=	$(DTBO-AMLOGIC) $(DTBO-ROCKCHIP) $(DTBO-ALLWINNER)
TMP		:=	$(addsuffix .tmp,$(DTBO))

.PHONY: all
all: build

#
# Test
#
.PHONY: test
test:

#
# Build
#
.PHONY: build
build: build-doc

.PHONY: build-dtbo
build-dtbo: $(DTBO)

%.dtbo: %.dts
	cpp -nostdinc -undef -x assembler-with-cpp -E -I "$(KSRC)/include" "$<" "$@.tmp"
	dtc -@ -I dts -O dtb -o "$@" "$@.tmp"

DOCS		:=	SOURCE
.PHONY: build-doc
build-doc: $(DOCS)

.PHONY: SOURCE
SOURCE: 
	echo -e "git clone $(shell git remote get-url origin)\ngit checkout $(shell git rev-parse HEAD)" > "$@"

#
# Clean
#
.PHONY: distclean
distclean: clean


.PHONY: clean-dtbo
clean-dtbo:
	rm -rf $(DTBO) $(TMP)

.PHONY: clean
clean: clean-dtbo
	rm -rf debian/.debhelper debian/radxa-overlays-dkms \
		debian/debhelper-build-stamp debian/files debian/*.debhelper.log \
		debian/*.*.debhelper debian/*.substvars debian/tmp \
		.Module.symvers.cmd \
		.modules.order.cmd \
		Module.symvers \
		modules.order \
		.radxa-overlays.* \
		radxa-overlays.*

#
# Release
#
.PHONY: dch
dch: debian/changelog
	EDITOR=true gbp dch --ignore-branch --multimaint-merge --commit --release --dch-opt=--upstream

.PHONY: deb
deb: debian
	debuild --no-lintian --lintian-hook "lintian --fail-on error,warning --suppress-tags bad-distribution-in-changes-file -- %p_%v_*.changes" --no-sign -b

.PHONY: release
release:
	gh workflow run .github/workflows/new_version.yml --ref $(shell git branch --show-current)
