# Node.js Snap for https://snapcraft.io/

[![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-white.svg)](https://snapcraft.io/node)

[Snaps](https://snapcraft.io/about) are:

> app packages for desktop, cloud and IoT that are easy to install, secure, cross‐platform and dependency‐free. Snaps are discoverable and installable from the Snap Store, the app store for Linux with an audience of millions.

The Snap managed from this repository is available as `node` from the Snap store and contains the Node.js runtime and [npm](https://www.npmjs.com/). Tracks before Node.js 26 also include [Yarn Classic](https://classic.yarnpkg.com/). They are automatically built and pushed for each supported release line and nightly versions straight from the `main` branch. Once initially installed, new versions of Node.js for the release line you've chosen are automatically updated to your computer within hours of their release on [nodejs.org](https://nodejs.org/).

* [Installation](#installation)
  * [Switching release lines](#switching-release-lines)
  * [Nightly ("edge") versions](#nightly-edge-versions)
* [How publishing happens](#how-publishing-happens)
  * [Snap configuration](#snap-configuration)
  * [Watching for releases](#watching-for-releases)
  * [Building Snaps](#building-snaps)
  * [Adding new release lines](#adding-new-release-lines)
    * [Removing old release lines](#removing-old-release-lines)
  * [Default release line](#default-release-line)

## Installation

The `snap` command ships with Ubuntu and is available to be installed in most popular Linux distributions. If you do not have it installed, follow the instructions on Snapcraft to install [_snapd_](https://docs.snapcraft.io/core/install).

Snaps are delivered via "channels". For Node.js, the channel names are the major-version number of Node.js. So select a supported Node.js version and install with:

```
sudo snap install node --classic --channel=14
```

Substituting `14` for the major version you want to install. Both LTS and Current versions of Node.js are available.

Once installed, the `node` and `npm` commands are available for use. Tracks before Node.js 26 also provide `yarn`. All commands remain updated for the channel you selected.

The `--classic` argument is required here as Node.js needs full access to your system in order to be useful, therefore it needs Snap's "classic confinement". By default, Snaps are much more restricted in their ability to access your disk and network and must request special access from you where they need it.

### Switching release lines

You can use the `refresh` command to switch to a new channel at any time:

```
sudo snap refresh node --channel=15
```

Once switched, snapd will update Node.js for the new channel you have selected.

### Nightly ("edge") versions

The `main` branch from the Node.js [git repository](https://github.com/nodejs/node) is pushed to the Snap store nightly and is available from the `edge` channel.

```
sudo snap install node --classic --channel=edge
```

## How publishing happens

The pipeline from releases to the Snap store is complicated and involves many moving pieces. This repository serves as the connection between [nodejs.org/download/](https://nodejs.org/download/), where releases are published, and the Canonical Snap toolchain that builds the snaps ([Launchpad](https://launchpad.net)) and publishes them ([Snapcraft](https://snapcraft.io)).

### Snap configuration

This repository contains a main script [snapcraft.yaml.sh](./snapcraft.yaml.sh), and a Snap build definition file that it creates, [snapcraft.yaml](./snapcraft.yaml). **snapcraft.yaml should never be edited manually**, it is the product of the script.

This repository contains a branch for each track/channel published to the Snap store. The `main` branch represents the "edge" channel, while the `nodeXX` branches represent the major release lines (e.g. `node14` for Node.js 14.x.x). These release lines are published to the "stable" channel on a track named after the release line. e.g. Node.js 14.x.x releases are published as `14/stable`.

Each branch contains its own snapcraft.yaml.sh script and generated snapcraft.yaml definition. These may differ as release artifact availability and source-build requirements change.

**Changes to the build definition should be made in the snapcraft.yaml.sh script for the relevant branch.** For changes to "edge" (nightly / main) releases, change the snapcraft.yaml.sh script on the `main` branch. For changes to the "14/stable" releases, change the snapcraft.yaml.sh on the `node14` branch. All changes should be made via Pull Request targeting the appropriate branch.

### Watching for releases

This repository uses an hourly or manually dispatched GitHub Actions workflow. See [.github/workflows/cron.yml](./.github/workflows/cron.yml). Its matrix contains `main` and each major release line currently published to the Snap store. Jobs for the same branch are serialized.

For each branch, the workflow checks out its current tip and runs snapcraft.yaml.sh. `-rXX` selects a release line (for example, `-r24`); the option is omitted for edge releases.

The generator reads either the [release index](https://nodejs.org/download/release/index.tab) or [nightly index](https://nodejs.org/download/nightly/index.tab). It selects the newest entry containing every artifact required by that branch, skipping newer incomplete entries. It then requires each selected filename in the release's `SHASUMS256.txt` and embeds the checksums in snapcraft.yaml.

When snapcraft.yaml changes, the workflow commits and pushes it to the corresponding GitHub branch. The same branch tip is always pushed to Launchpad, allowing a prior failed synchronization to recover on the next run. Workflow runs do not trigger from their own pushes.

### Runtime artifacts and architectures

On amd64, arm64 and s390x, the Snap packages Node.js' official Linux binaries without changing their ELF interpreter or runtime search paths. These binaries retain Node.js' upstream Linux ABI baseline and load libc and libstdc++ from the host, matching a normally installed Node.js runtime. Node.js 25 and later also require `libatomic.so.1`; the Snap provides only that library in an isolated directory without redirecting other runtime libraries.

Node.js does not publish an armv7 Linux binary from Node.js 24 onward. The armhf Snap therefore remains an Experimental source build and uses Snapcraft's architecture-aware ELF patching against the base Snap. Node.js 22 uses its official armv7l artifact instead. This split also provides a documented source-build path for future Experimental architectures without weakening the supported architectures' compatibility.

The Snap prepends its direct `bin` directory to `PATH` so npm lifecycle scripts and child processes resolve `node`, `npm` and `npx` without re-entering the `/snap/bin` launcher. This does not affect external programs that explicitly invoke `/snap/bin/node`.

### Building Snaps

A mirror of this repository is maintained on Canonical's [Launchpad](https://launchpad.net) at <https://code.launchpad.net/node-snap>. Launchpad has integration with the [Snap store](https://snapcraft.io) and has builders for many different platforms that can build Snap packages with minimal additional configuration.

When changes are made to the snapcraft.yaml file for each branch on this repository, the changes are also pushed to https://code.launchpad.net/node-snap for the same branch.

For each branch we are releasing to the Snap store, we have a Snap build configuration set up in Launchpad (the setup is a manual process for an authorized user at the beginning of each release line). Changes to the branch result in new Snap package builds from the snapcraft.yaml definition file. Once successfully built, the packages are pushed to the Snap store for the relevant track/channel.

### Adding new release lines

The process for adding new release lines when the Node.js Release team begin one is a multi-step process, some of these steps can be contributed to this repository by anybody via Pull Request:

1. Request a new Track for the "node" Snap in the Snapcraft forum in the ["Store requests" section](https://forum.snapcraft.io/c/store-requests). The track should be the major release line number (e.g. `14`). The "node" Snap has fast-track approval and is usually authorized within 24 hours by the administrators. This step needs to be performed in order to upload to a new track. An example of this for `14` can be seen here: https://forum.snapcraft.io/t/track-request-for-node-14-fast-track-please/16842/3
2. Create a new branch in this repository, named `nodeXX` where `XX` is the release line number.
3. Edit [snapcraft.yaml.sh](./snapcraft.yaml.sh) if artifact availability or the Experimental source-build toolchain differs from `main`. In most cases the `main` version can be copied unchanged.
4. Edit [.github/workflows/cron.yml](./.github/workflows/cron.yml) to add the new release line to the matrix.
5. Run the GitHub workflow manually or wait for its hourly schedule. It will update snapcraft.yaml and push the branch to https://code.launchpad.net/node-snap.
6. Navigate to https://code.launchpad.net/node-snap and into the new branch and click on "Create snap package".
  - The "name" should be the same as the branch
  - The "series" should be inferred from snapcraft.yaml
  - The "processors" should be _at least_: armhf, arm64, amd64, i386, ppc64el, s390x
  - "Automatically build when branch changes" should be ticked.
  - "Automatically upload to store" should be ticked
  - "Registered store package name" should be "node"
  - "Risk" should be "stable" (this is "edge" for nightly builds)
  - "Track" should be the major release line
  - Clicking "Create snap package" should create the workflow and authenticate the publishing with the Snap store (this is a simple multi-step authorization process).
7. Manually request new builds for the Snap from the Snap configuration page in Launchpad ("Request builds").

Note that at the time of writing, Snap store authorization for Launchpad has an expiry of 2 years. This can cause Snaps to fail to upload and may not result in a warning. This can be a problem for LTS lines.

#### Removing old release lines

When release lines stop seeing new releases, they can be removed from [.github/workflows/cron.yml](./.github/workflows/cron.yml). This stops the entire pipeline from running (although changes to the relevant branch will not even occur without new releases on nodejs.org). The Snap configuration in Launchpad can also be removed but this is not strictly necessary.

### Default release line

Snaps can have a "default" track. This default determines which track is installed if the user doesn't set one (e.g. with `sudo snap install node`). It is up to the Snap author to set this default and update it as appropriate. Users don't follow the default track, it only determines the starting track at time of install. Changing default in the Snap store doesn't impact existing users, only new installs

The Node.js Snap should have its "default" set to the most recent LTS. This can be done in the Releases page by a Node.js Snap administrator: https://snapcraft.io/node/releases and should be done as soon as a release line enters **Active LTS** as per the [Release Schedule](https://github.com/nodejs/release#release-schedule).

This is a manual procedure and may require reminders posted to this repository from the community.
