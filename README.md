# Node.js Snap for https://snapcraft.io/

[![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-white.svg)](https://snapcraft.io/node)

[Snaps](https://snapcraft.io/about) are:

> app packages for desktop, cloud and IoT that are easy to install, secure, cross‐platform and dependency‐free. Snaps are discoverable and installable from the Snap Store, the app store for Linux with an audience of millions.

The Snap managed from this repository is available as `node` from the Snap store and contains the Node.js runtime, along with the two most widely-used package managers, [npm](https://www.npmjs.com/) and [Yarn](https://yarnpkg.com). They are automatically built and pushed for each supported release line and nightly versions straight from the `master` branch. Once initially installed, new versions of Node.js for the release line you've chosen are automatically updated to your computer within hours of their release on [nodejs.org](https://nodejs.org/).

### Installation

The `snap` command ships with Ubuntu and is available to be installed in most popular Linux distributions. If you do not have it installed, follow the instructions on snapcraft to install [_snapd_](https://docs.snapcraft.io/core/install).

Snaps are delivered via "channels". For Node.js, the channel names are the major-version number of Node.js. So select a supported Node.js version and install with:

```
sudo snap install node --classic --channel=14
```

Substituting `14` for the major version you want to install. Both LTS and Current versions of Node.js are available.

Once installed, the `node`, `npm` and `yarn` commands are available for use and will remain updated for the channel you selected.

The `--classic` argument is required here as Node.js needs full access to your system in order to be useful, therefore it needs Snap's "classic confinement". By default, Snaps are much more restricted in their ability to access your disk and network and must request special access from you where they need it.

#### Switching release lines

You can use the `refresh` command to switch to a new channel at any time:

```
sudo snap refresh node --channel=15
```

Once switched, snapd will update Node.js for the new channel you have selected.

#### Nightly versions

The `master` branch from the Node.js [git repository](https://github.com/nodejs/node) are pushed to the Snap store nightly and are available from the `edge` channel.

```
sudo snap install node --classic --channel=edge
```
