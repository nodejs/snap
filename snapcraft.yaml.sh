#!/bin/bash

set -euxo pipefail

__dirname="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

select_node_version() {
  local index_url="$1"
  local major="$2"
  local required_files="$3"

  curl -sL --show-error --fail "$index_url" |
    awk -F '\t' -v major="$major" -v required_files="$required_files" '
      function includes(files, candidate, count, loop_index, values) {
        count = split(files, values, ",")
        for (loop_index = 1; loop_index <= count; loop_index++) {
          if (values[loop_index] == candidate) {
            return 1
          }
        }
        return 0
      }

      NR > 1 && !selected && (major == "" || index($1, "v" major ".") == 1) {
        required_count = split(required_files, required, ",")
        complete = 1
        for (required_index = 1; required_index <= required_count; required_index++) {
          if (!includes($3, required[required_index])) {
            complete = 0
          }
        }
        if (complete) {
          selected = 1
          print substr($1, 2)
        }
      }

      END {
        if (!selected) {
          exit 1
        }
      }
    '
}

checksum_for() {
  local filename="$1"

  awk -v filename="$filename" '
    $2 == filename {
      found = 1
      print $1
      exit
    }

    END {
      if (!found) {
        exit 1
      }
    }
  ' <<< "$NODE_SHASUMS"
}

NODE_REQUIRED_FILES="src,linux-arm64,linux-s390x,linux-x64"
NODE_ARMHF_MODE=source

while getopts ":r:" opt; do
  case $opt in
    r)
      echo "Updating for latest $OPTARG release" >&2
      NODE_DISTTYPE="release"
      NODE_TAG=""
      if [ "$OPTARG" -le 22 ]; then
        NODE_REQUIRED_FILES+=",linux-armv7l"
        NODE_ARMHF_MODE=prebuilt
      fi
      NODE_VERSION="$(select_node_version "https://nodejs.org/download/release/index.tab" "$OPTARG" "$NODE_REQUIRED_FILES")"
      ;;
    :)
      echo "Option -$OPTARG requires an argument" >&2
      exit 1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
  esac
done

if [ -z ${NODE_DISTTYPE+x} ]; then
  NODE_DISTTYPE="nightly"
  NODE_VERSION="$(select_node_version "https://nodejs.org/download/nightly/index.tab" "" "$NODE_REQUIRED_FILES")"
  NODE_TAG="$(echo "$NODE_VERSION" | sed -E 's/^[^-]+-//')"
fi

NODE_DOWNLOAD_BASE="https://nodejs.org/download/${NODE_DISTTYPE}/v${NODE_VERSION}"
NODE_SHASUMS="$(curl -sL --show-error --fail "${NODE_DOWNLOAD_BASE}/SHASUMS256.txt")"
NODE_SOURCE_ARCHIVE="node-v${NODE_VERSION}.tar.xz"
NODE_X64_ARCHIVE="node-v${NODE_VERSION}-linux-x64.tar.xz"
NODE_ARM64_ARCHIVE="node-v${NODE_VERSION}-linux-arm64.tar.xz"
NODE_S390X_ARCHIVE="node-v${NODE_VERSION}-linux-s390x.tar.xz"
NODE_SOURCE_CHECKSUM="$(checksum_for "$NODE_SOURCE_ARCHIVE")"
NODE_X64_CHECKSUM="$(checksum_for "$NODE_X64_ARCHIVE")"
NODE_ARM64_CHECKSUM="$(checksum_for "$NODE_ARM64_ARCHIVE")"
NODE_S390X_CHECKSUM="$(checksum_for "$NODE_S390X_ARCHIVE")"
NODE_ARMHF_ARCHIVE=""
NODE_ARMHF_CHECKSUM=""
if [ "$NODE_ARMHF_MODE" = "prebuilt" ]; then
  NODE_ARMHF_ARCHIVE="node-v${NODE_VERSION}-linux-armv7l.tar.xz"
  NODE_ARMHF_CHECKSUM="$(checksum_for "$NODE_ARMHF_ARCHIVE")"
fi

echo "NODE_VERSION=$NODE_VERSION"
echo "NODE_DISTTYPE=$NODE_DISTTYPE"
echo "NODE_TAG=$NODE_TAG"


# Write snapcraft.yaml for this config

cat > "${__dirname}/snapcraft.yaml" << EOF
name: node
version: '${NODE_VERSION:0:30}'
summary: Node.js
description: |
  A JavaScript runtime built on Chrome's V8 JavaScript engine. Node.js uses an event-driven, non-blocking I/O model that makes it lightweight and efficient. Node.js' package ecosystem, npm, is the largest ecosystem of open source libraries in the world. https://nodejs.org/

grade: stable
confinement: classic
base: core24

environment:
  PATH: '\$SNAP/bin:\$PATH'
  LD_LIBRARY_PATH: '\$SNAP/lib/runtime'

apps:
  node:
    command: bin/node
  npm:
    command: bin/npm
  npx:
    command: bin/npx

parts:
  node-prebuilt:
    plugin: nil
    build-attributes:
      - no-patchelf
    build-packages:
      - curl
      - xz-utils
    override-pull: |
      case "\$CRAFT_ARCH_BUILD_FOR" in
        amd64)
          archive="${NODE_X64_ARCHIVE}"
          checksum="${NODE_X64_CHECKSUM}"
          ;;
        arm64)
          archive="${NODE_ARM64_ARCHIVE}"
          checksum="${NODE_ARM64_CHECKSUM}"
          ;;
        s390x)
          archive="${NODE_S390X_ARCHIVE}"
          checksum="${NODE_S390X_CHECKSUM}"
          ;;
        armhf)
          if [ "${NODE_ARMHF_MODE}" != "prebuilt" ]; then
            exit 0
          fi
          archive="${NODE_ARMHF_ARCHIVE}"
          checksum="${NODE_ARMHF_CHECKSUM}"
          ;;
        *)
          echo "Unsupported architecture: \$CRAFT_ARCH_BUILD_FOR" >&2
          exit 1
          ;;
      esac
      cd "\$CRAFT_PART_SRC"
      curl -sSL --show-error --fail --proto '=https' --tlsv1.2 \
        --output "\$archive" "${NODE_DOWNLOAD_BASE}/\$archive"
      echo "\$checksum  \$archive" | sha256sum --check --strict -
      tar -xJf "\$archive" --strip-components=1
      rm "\$archive"
    override-build: |
      if [ "\$CRAFT_ARCH_BUILD_FOR" = "armhf" ] && [ "${NODE_ARMHF_MODE}" != "prebuilt" ]; then
        exit 0
      fi
      craftctl default
      cp -a "\$CRAFT_PART_SRC"/. "\$CRAFT_PART_INSTALL"/
      mkdir -p "\$CRAFT_PART_INSTALL/etc"
      echo "prefix = /usr/local" >> "\$CRAFT_PART_INSTALL/etc/npmrc"

  node-libatomic:
    plugin: nil
    build-attributes:
      - no-patchelf
    build-packages:
      - libatomic1
    override-build: |
      craftctl default
      install -Dm644 \
        "/usr/lib/\$CRAFT_ARCH_TRIPLET_BUILD_FOR/libatomic.so.1" \
        "\$CRAFT_PART_INSTALL/lib/runtime/libatomic.so.1"

  node-experimental:
    plugin: make
    source: .
    build-attributes:
      - enable-patchelf
    build-snaps:
      - to armhf:
          - rustup/latest/stable
    build-packages:
      - curl
      - xz-utils
      - to armhf:
          - gcc-14
          - g++-14
    stage-packages:
      - to armhf:
          - libstdc++6
          - libgcc-s1
    build-environment:
      - CC: gcc-14
      - CXX: g++-14
      - LINK: g++-14
      - RUSTUP_TOOLCHAIN: "1.83.0"
      - V: ""
    make-parameters:
      - V=
    override-pull: |
      if [ "${NODE_ARMHF_MODE}" != "source" ] || [ "\$CRAFT_ARCH_BUILD_FOR" != "armhf" ]; then
        exit 0
      fi
      cd "\$CRAFT_PART_SRC"
      archive="${NODE_SOURCE_ARCHIVE}"
      curl -sSL --show-error --fail --proto '=https' --tlsv1.2 \
        --output "\$archive" "${NODE_DOWNLOAD_BASE}/\$archive"
      echo "${NODE_SOURCE_CHECKSUM}  \$archive" | sha256sum --check --strict -
      tar -xJf "\$archive" --strip-components=1
      rm "\$archive"
    override-build: |
      if [ "${NODE_ARMHF_MODE}" != "source" ] || [ "\$CRAFT_ARCH_BUILD_FOR" != "armhf" ]; then
        exit 0
      fi
      rustup toolchain install "\$RUSTUP_TOOLCHAIN" --profile minimal
      ./configure --verbose --prefix=/ --release-urlbase=https://nodejs.org/download/${NODE_DISTTYPE}/ --tag=${NODE_TAG} --v8-enable-temporal-support
      craftctl default
      mkdir -p "\$CRAFT_PART_INSTALL/etc"
      echo "prefix = /usr/local" >> "\$CRAFT_PART_INSTALL/etc/npmrc"
EOF

