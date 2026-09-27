.PHONY: release lint clean

release:
	./release.sh

lint:
	shellcheck -x install.sh uninstall.sh release.sh gdm/gdm.sh plymouth/plymouth.sh lib/common.sh

clean:
	rm -rf dist
