#!/bin/sh

SCRIPTDIR=$(dirname $0)
VMCDIR=$(dirname $SCRIPTDIR)

set -e

pushd $VMCDIR

git fetch --tags
git checkout latest-staging

gem uninstall vmc --all --ignore-dependencies --executables

rm -f vmc-*.gem
gem build vmc.gemspec

popd

gem install $VMCDIR/vmc-*.gem

gem uninstall cfoundry --all --ignore-dependencies --executables

git clone git://github.com/cloudfoundry/vmc-lib.git vmc-lib-tmp
# TODO: checkout latest-vmc?
pushd vmc-lib-tmp
gem build cfoundry.gemspec
gem install cfoundry-*.gem
popd
rm -rf vmc-lib-tmp

vmc -v
