DEST := /usr/local/bin/swift-sh
BUILD_PATH=$(shell swift build --show-bin-path --configuration release)

build:
	swift build --configuration release
	@echo built at ${BUILD_PATH}
install: build
	mv ${BUILD_PATH}/swift-sh ${DEST}
	chmod 755 ${DEST}
	@echo installed at ${DEST}
uninstall:
	rm ${DEST}
clean:
	rm -rf .build

