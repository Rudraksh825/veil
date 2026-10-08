.PHONY: app debug run install clean

app:            ## Build release .app into build/
	./build.sh release

debug:          ## Build debug .app into build/
	./build.sh debug

run: app        ## Build and launch
	open build/Veil.app

install: app    ## Build and copy to /Applications
	rm -rf /Applications/Veil.app
	cp -R build/Veil.app /Applications/Veil.app
	@echo "✓ Installed /Applications/Veil.app"

clean:
	rm -rf .build build
