
default:
    @echo "script for iDebugger"

build +args="":
    swift build --sdk $(xcrun --sdk iphoneos --show-sdk-path) --triple arm64-apple-ios13.0 {{args}}

release version:
    #!/usr/bin/env bash
    set -euo pipefail

    # check if the git repo is dirty or not
    if [ -n "$(git status --porcelain)" ]; then
        echo "Git repository is dirty. Please commit or stash your changes before setting the version."
        exit 1
    fi

    # check if it's in master branch or not
    if [ "$(git rev-parse --abbrev-ref HEAD)" != "master" ]; then
        echo "Not in master branch. Please switch to master branch before setting the version."
        exit 1
    fi

    echo "Running lint..."
    pod lib lint --allow-warnings --use-libraries *.podspec --silent
    just build --quiet

    echo "{{version}}" > .version
    git add .version
    git commit -m "Release {{version}}"
    git tag -a {{version}} -m "Version {{version}}"

    echo "Pushing changes to remote repository..."
    git push origin master
    git push origin {{version}}
