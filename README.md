# Node.js Snap for https://snapcraft.io/

[![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-white.svg)](https://snapcraft.io/node)

[Snaps](https://snapcraft.io/about) are:

> app packages for desktop, cloud and IoT that are easy to install, secure, cross‐platform and dependency‐free. Snaps are discoverable and installable from the Snap Store, the app store for Linux with an audience of millions.

The Snap managed from this repository is available as `node` from the Snap store and contains the Node.js runtime, along with the two most widely-used package managers, [npm](https://www.npmjs.com/) and [Yarn](https://yarnpkg.com). They are automatically built and pushed for each supported release line and nightly versions straight from the `master` branch. Once initially installed, new versions of Node.js for the release line you've chosen are automatically updated to your computer within hours of their release on [nodejs.org](https://nodejs.org/).

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

Once installed, the `node`, `npm` and `yarn` commands are available for use and will remain updated for the channel you selected.

The `--classic` argument is required here as Node.js needs full access to your system in order to be useful, therefore it needs Snap's "classic confinement". By default, Snaps are much more restricted in their ability to access your disk and network and must request special access from you where they need it.

### Switching release lines

You can use the `refresh` command to switch to a new channel at any time:

```
sudo snap refresh node --channel=15
```

Once switched, snapd will update Node.js for the new channel you have selected.

### Nightly ("edge") versions

The `master` branch from the Node.js [git repository](https://github.com/nodejs/node) are pushed to the Snap store nightly and are available from the `edge` channel.

```
sudo snap install node --classic --channel=edge
```

## How publishing happens

The pipeline from releases to the Snap store is complicated and involves many moving pieces. This repository serves as the connection between [nodejs.org/download/](https://nodejs.org/download/), where releases are published, and the Canonical Snap toolchain that builds the snaps ([Launchpad](https://launchpad.net)) and publishes them ([Snapcraft](https://snapcraft.io)).

### Snap configuration

This repository contains a master script [snapcraft.yaml.sh](./snapcraft.yaml.sh), and a Snap build definition file that it creates, [snapcraft.yaml](./snapcraft.yaml). **snapcraft.yaml should never be edited manually**, it is the product of the script.

This repository contains a branch for each track/channel published to the Snap store. The `master` branch represents the "edge" channel, while the `nodeXX` branches represent the major release lines (e.g. `node14` for Node.js 14.x.x). These release lines are published to the "stable" channel on a track named after the release line. e.g. Node.js 14.x.x releases are published as `14/stable`.

Each branch, contains both a snapcraft.yaml.sh script and a snapcraft.yaml definition file. These are different between releases as compile requirements change.

**Changes to the build definition should be made in the snapcraft.yaml.sh script for the relevant branch.** For changes to "edge" (nightly / master) releases, change the snapcraft.yaml.sh script on the `master` branch. For changes to the "14/stable" releases, change the snapcraft.yaml.sh on the `node14` branch. All changes should be made via Pull Request targeting the appropriate branch.

### Watching for releases

This repository uses GitHub Actions on a timer (cron) schedule. See [.github/workflows/cron.yml](./.github/workflows/cron.yml). The Action configuration is set to run for the `master` branch and for each major release line that is currently being published to the Snap store using a matrix configuration.

Upon run, for each branch, this repository is cloned and the snapcraft.yaml.sh script is run with arguments that tell it what to do. `-rXX` is supplied to specify the release line (e.g. `-r14`, this is omitted for "edge" releases) and `-gnode14` is supplied to specify the Git branch to operate on (more on this below).

The snapcraft.yaml.sh script will fetch the relevant releases list, either https://nodejs.org/download/release/index.tab for regular releases, or https://nodejs.org/download/nightly/index.tab for "edge" releases. The latest release for the given release line (or latest nightly release) is then used to build the snapcraft.yaml Snap definition file.

In most cases, building a new snapcraft.yaml file will result in the same file already in this repository. But when there is a new release for that release line, the file will differ. When it differs it is committed and pushed back to this repository on the appropriate branch.

When changes are made, the commit is _also_ pushed to Launchpad to build the Snap.

### Building Snaps

A mirror of this repository is maintained on Canonical's [Launchpad](https://launchpad.net) at <https://code.launchpad.net/node-snap>. Launchpad has integration with the [Snap store](https://snapcraft.io) and has builders for many different platforms that can build Snap packages with minimal additional configuration.

When changes are made to the snapcraft.yaml file for each branch on this repository, the changes are also pushed to https://code.launchpad.net/node-snap for the same branch.

For each branch we are releasing to the Snap store, we have a Snap build configuration set up in Launchpad (the setup is a manual process for an authorized user at the beginning of each release line). Changes to the branch result in new Snap package builds from the snapcraft.yaml definition file. Once successfully built, the packages are pushed to the Snap store for the relevant track/channel.

### Adding new release lines

The process for adding new release lines when the Node.js Release team begin one is a multi-step process, some of these steps can be contributed to this repository by anybody via Pull Request:

1. Request a new Track for the "node" Snap in the Snapcraft forum in the ["Store requests" section](https://forum.snapcraft.io/c/store-requests). The track should be the major release line number (e.g. `14`). The "node" Snap has fast-track approval and is usually authorized within 24 hours by the administrators. This step needs to be performed in order to upload to a new track. An example of this for `14` can be seen here: https://forum.snapcraft.io/t/track-request-for-node-14-fast-track-please/16842/3
2. Create a new branch in this repository, named `nodeXX` where `XX` is the release line number.
3. Edit [snapcraft.yaml.sh](./snapcraft.yaml.sh) _if_ required for system configuration required to build the new version. In most cases this is not necessary and the `master` version can be copied. Where the compiler minimums change, the equivalent changes may need to be made in the script.
4. Edit [.github/workflows/cron.yml](./.github/workflows/cron.yml) to add the new release line to the matrix.
5. Start a build (manually, or wait for the GitHub Action to trigger by cron), which will update the snapcraft.yaml file for that branch correctly _and_ push the new branch to https://code.launchpad.net/node-snap where it can be further configured.
6. Navigate to https://code.launchpad.net/node-snap and into the new branch and click on "Create snap package".
  - The "name" should be the same as the branch
  - The "series" should be inferred from snapcraft.yaml
  - The "processors" should be _at least_: armhf, arm64, amd64, i386
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
