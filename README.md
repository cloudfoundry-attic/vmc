[![Build Status](https://travis-ci.org/cloudfoundry/vmc.png)](https://travis-ci.org/cloudfoundry/vmc)

# CLI for Cloud Foundry (ng or next generation or v2)

The CLI for Cloud Foundry is being completely rewritten in the `ng` branch. Installation, usage & contribution instructions are below.

To use this CLI, your Cloud Foundry installation will need to be running <a href="https://github.com/cloudfoundry/cloud_controller_ng">cloud_controller_ng</a>, which is a part of the latest <a href="https://github.com/cloudfoundry/cf-release/tree/master/jobs/cloud_controller_ng">cf-release</a>, but not yet part of Micro Cloud Foundry. That is, you can use this CLI against <a href="http://api.cloudfoundry.com" title="">http://api.cloudfoundry.com</a> but not the local VM version of Cloud Foundry.

To use new features of the v2 CLI, you will also need to follow the "Using v2 features" section below.

## Public Cloud Foundries running Cloud Controller NG

You can use this ng/nextgen version of VMC with the following public hosts of Cloud Foundry:

* <a href="http://CloudFoundry.com">CloudFoundry.com</a>

Please submit a gerrit patch to update this list if your company is running cloud_controller_ng for its customers.

## Additional articles about VMC v2

* <a href="http://www.iamjambay.com/2012/10/cloud-foundry-vmc-ng-has-helpful-client.html" title="i am jambay: Cloud Foundry VMC-ng Has Helpful Client Logging">Cloud Foundry VMC-ng Has Helpful Client Logging</a>

## Installation

```
$ gem install vmc
$ vmc -v
vmc 0.4.2
```

## Development

```
$ gerrit clone ssh://$(whoami)@reviews.cloudfoundry.org:29418/vmc
$ cd vmc
$ bundle install
$ rake gem:install
```

## Usage

```
$ vmc help --all
Getting Started
  info            	Display information on the current target, user, etc.
  target [URL]    	Set or display the target cloud, organization, and space
  targets         	List known targets.
  login [USERNAME]	Authenticate with the target
  logout          	Log out from the target
  register [EMAIL]	Create a user and log in
  colors          	Show color configuration

Applications
  app [APP]	Show app information
  apps     	List your applications

  Management
    delete APPS...     	Delete an application
    push [NAME]        	Push an application, syncing changes if it exists
    rename [APP] [NAME]	Rename an application
    restart APPS...    	Stop and start an application
    start APPS...      	Start an application
    stop APPS...       	Stop an application

  Information
    crashes APPS...         	List an app's crashed instances
    env [APP]               	Show all environment variables set for an app
    set-env APP NAME [VALUE]	Set an environment variable
    unset-env APP NAME      	Remove an environment variable
    file APP [PATH]         	Print out an app's file contents
    files APP [PATH]        	Examine an app's files
    tail APP [PATH]         	Stream an app's file contents
    health APPS...          	Get application health
    instances APPS...       	List an app's instances
    logs [APP]              	Print out an app's logs
    crashlogs APP           	Print out the logs for an app's crashed instances
    map APP URL             	Add a URL mapping for an app
    unmap APP [URL]         	Remove a URL mapping from an app
    scale [APP]             	Update the instances/memory limit for an application
    stats [APP]             	Display application instance status

Services
  service INSTANCE	Show service instance information
  services        	List your service instances

  Management
    bind-service [INSTANCE] [APP]  	Bind a service instance to an application
    unbind-service [INSTANCE] [APP]	Unbind a service from an application
    create-service [SERVICE] [NAME]	Create a service
    delete-service [INSTANCE]      	Delete a service
    rename-service [SERVICE] [NAME]	Rename a service
    tunnel [INSTANCE] [CLIENT]     	Tells you to install tunnel-vmc-plugin

Organizations
  create-org [NAME]               	Create an organization
  delete-org [ORGANIZATION]       	Delete an organization
  org [ORGANIZATION]              	Show organization information
  orgs                            	List available organizations
  rename-org [ORGANIZATION] [NAME]	Rename an organization

Spaces
  create-space [NAME] [ORGANIZATION]	Create a space in an organization
  delete-space SPACES...            	Delete a space and its contents
  rename-space [SPACE] [NAME]       	Rename a space
  space [SPACE]                     	Show space information
  spaces [ORGANIZATION]             	List spaces in an organization
  take-space NAME                   	Switch to a space, creating it if it doesn't exist

Routes
  create-route [URL]  	Create a route
  delete-route [ROUTE]	Delete a route
  routes              	List routes in a space

Domains
  add-domain NAME       	Add a domain to a space
  create-domain NAME    	Create a domain
  delete-domain [DOMAIN]	Delete a domain
  domains [SPACE]       	List domains in a space
  remove-domain [DOMAIN]	Remove a domain from a space

Administration
  users	List all users

  User Management
    create-user [EMAIL]	Create a user
    delete-user EMAIL  	Delete a user
    passwd [USER]      	Update a user's password

Options:
      --[no-]color       Use colorful output
      --[no-]script      Shortcut for --quiet and --force
  -V, --verbose          Print extra information
  -f, --[no-]force       Skip interaction when possible
  -h, --help             Show command usage & instructions
  -m, --manifest FILE    Path to manifest file to use
  -q, --[no-]quiet       Simplify output format
  -t, --trace            Show API requests and responses
  -u, --proxy EMAIL      Act as another user (admin only)
  -v, --version          Print version number
```

## Learn

There is a Cloud Foundry documentation set for open source developers, and one for CloudFoundry.com users:

* Open Source Developers: [https://github.com/cloudfoundry/oss-docs](https://github.com/cloudfoundry/oss-docs)
* CloudFoundry.com users: [http://docs.cloudfoundry.com](http://docs.cloudfoundry.com)

To make changes to our documentation, follow the [OSS Contributions][OSS Contributions] steps and contribute to the oss-docs repository.

## Ask Questions

Questions about the Cloud Foundry Open Source Project can be directed to our Google Groups.

* BOSH Developers: [https://groups.google.com/a/cloudfoundry.org/group/bosh-dev/topics](https://groups.google.com/a/cloudfoundry.org/group/bosh-dev/topics)
* BOSH Users:[https://groups.google.com/a/cloudfoundry.org/group/bosh-users/topics](https://groups.google.com/a/cloudfoundry.org/group/bosh-users/topics)
* VCAP (Cloud Foundry) Developers: [https://groups.google.com/a/cloudfoundry.org/group/vcap-dev/topics](https://groups.google.com/a/cloudfoundry.org/group/vcap-dev/topics)

Questions about CloudFoundry.com can be directed to: [http://support.cloudfoundry.com](http://support.cloudfoundry.com)

## File a Bug

To file a bug against Cloud Foundry Open Source and its components, sign up and use our bug tracking system: [http://cloudfoundry.atlassian.net](http://cloudfoundry.atlassian.net)

## OSS Contributions

The Cloud Foundry team uses Gerrit, a code review tool that originated in the Android Open Source Project. We also use GitHub as an official mirror, though all pull requests are accepted via Gerrit.

Follow our [Workflow process](https://github.com/cloudfoundry/oss-docs/blob/master/workflow.md "Workflow Process") to make a contribution to any of our open source repositories.
