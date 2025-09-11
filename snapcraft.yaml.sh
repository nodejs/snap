#!/bin/bash

set -euxo pipefail

__dirname="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_GIT=no

while getopts "r:g:" opt; do
  case $opt in
    r)
      echo "Updating for latest $OPTARG release" >&2
      # release
      NODE_VERSION="$(curl -sL --show-error --fail https://nodejs.org/download/release/index.tab | awk 'BEGIN { found = 0 } /^v'"$OPTARG"'\..*[^a-z0-9]src[^a-z0-9]/ && !found { found = 1; print substr($1, 2) }')"
      NODE_DISTTYPE="release"
      NODE_TAG=""
      ;;
    g)
      echo "Pushing to git $OPTARG" >&2
      UPDATE_GIT=yes
      GIT_BRANCH=$OPTARG
      REMOTE_BRANCH=$GIT_BRANCH
      if [ "X${GIT_BRANCH}" = "Xmain" ]; then
        REMOTE_BRANCH=master
      fi
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit
  esac
done

# not a release?
if [ -z ${NODE_DISTTYPE+x} ]; then
  # nightly
  NODE_VERSION="$(curl -sL --show-error --fail https://nodejs.org/download/nightly/index.tab | awk 'BEGIN { found = 0 } /^v[1-9].*[^a-z0-9]src[^a-z0-9]/ && !found { found = 1; print substr($1, 2) }')"
  NODE_DISTTYPE="nightly"
  NODE_TAG="$(echo "$NODE_VERSION" | sed -E 's/^[^-]+-//')"
fi

echo "NODE_VERSION=$NODE_VERSION"
echo "NODE_DISTTYPE=$NODE_DISTTYPE"
echo "NODE_TAG=$NODE_TAG"

if [ "X${UPDATE_GIT}" = "Xyes" ]; then
  git clean -fdx
  git reset HEAD --hard
  git fetch origin
  git checkout "origin/$GIT_BRANCH" --force
  git branch -D "$GIT_BRANCH" || true
  git checkout -b "$GIT_BRANCH"
fi

# Write snapcraft.yaml for this config

cat > "${__dirname}/snapcraft.yaml" << EOF
name: node
version: '${NODE_VERSION:0:30}'
summary: Node.js
description: |
  A JavaScript runtime built on Chrome's V8 JavaScript engine. Node.js uses an event-driven, non-blocking I/O model that makes it lightweight and efficient. Node.js' package ecosystem, npm, is the largest ecosystem of open source libraries in the world. https://nodejs.org/

grade: stable
confinement: classic
base: core22

apps:
  node:
    command: bin/node
  npm:
    command: bin/npm
  npx:
    command: bin/npx
  yarn:
    command: bin/yarn.js
  yarnpkg:
    command: bin/yarn.js

parts:
  node:
    plugin: make
    source-type: tar
    source: https://nodejs.org/download/${NODE_DISTTYPE}/v${NODE_VERSION}/node-v${NODE_VERSION}.tar.gz
    build-packages:
      # Ensure these and the build environment below match the minimum GCC and G++ versions for this Node release.
      # https://github.com/nodejs/node/blob/main/BUILDING.md#building-nodejs-on-supported-platforms
      - gcc-10
      - g++-10
      - python3-distutils
    stage-packages:
      # Include C++ runtime libraries that Node.js needs
      - libstdc++6
      - libgcc-s1
    build-environment:
      - CC: gcc-10
      - CXX: g++-10
      - LINK: g++-10
      - V: ""
    stage-packages:
      - libstdc++6
    make-parameters:
      - V=
      - LDFLAGS=-Wl,-rpath=/snap/node/current/lib/\$(SNAPCRAFT_ARCH_TRIPLET):/snap/node/current/usr/lib/\$(SNAPCRAFT_ARCH_TRIPLET):/snap/core22/current/lib/\$(SNAPCRAFT_ARCH_TRIPLET):/snap/core22/current/usr/lib/\$(SNAPCRAFT_ARCH_TRIPLET)
    override-build: |
      ./configure --verbose --prefix=/ --release-urlbase=https://nodejs.org/download/${NODE_DISTTYPE}/ --tag=${NODE_TAG}
      craftctl default
      mkdir -p \$CRAFT_PART_INSTALL/etc
      echo "prefix = /usr/local" >> \$CRAFT_PART_INSTALL/etc/npmrc
  yarn:
    source-type: tar
    source: https://yarnpkg.com/latest.tar.gz
    plugin: dump
    # Yarn has a problem with lifecycle scripts when used inside snap, they don't complete properly, with exit code !=0.
    # Replacing the spinner with proper stdio appears to fix it.
    override-build: |
      craftctl default
      chmod -R g-s \$CRAFT_PART_INSTALL
      sed -i "s/var stdio = spinner ? undefined : 'inherit';/var stdio = 'inherit';/" \$CRAFT_PART_INSTALL/lib/cli.js
EOF

if [ "X${UPDATE_GIT}" = "Xyes" ] && [ -n "$(git status --porcelain "$__dirname")" ]; then
  echo "Updating git repo and pushing ..."
  git commit "$__dirname" -m "snap: (auto) updated to ${NODE_VERSION}"
  git push origin "$GIT_BRANCH"
  git push launchpad "$GIT_BRANCH:$REMOTE_BRANCH"
fi
