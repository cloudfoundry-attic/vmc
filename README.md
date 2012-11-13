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
$ gem install vmc --pre
```

## Development

```
$ gerrit clone ssh://$(whoami)@reviews.cloudfoundry.org:29418/vmc
$ cd vmc
$ git checkout ng
$ bundle install
$ rake install
```

## Dual VMC

Once you have installed the ng version of VMC (for example, vmc 0.4.0.beta.84), you can use the stable VMC client at any time:

```
$ vmc _0.3.23_ -v  # stable CLI
vmc 0.3.23

$ vmc -v           # ng CLI
vmc 0.4.0.beta.84
```

## Usage

Activate the v2 features of VMC-ng

```
$ touch ~/.vmc/use-ng
```

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
  apps     	List your applications
  app [APP]	Show app information

  Management
    push [NAME]    	Push an application, syncing changes if it exists
    start APPS...  	Start an application
    stop APPS...   	Stop an application
    restart APPS...	Stop and start an application
    delete APPS... 	Delete an application

  Information
    instances APPS...       	List an app's instances
    crashes APPS...         	List an app's crashed instances
    scale [APP]             	Update the instances/memory limit for an application
    logs [APP]              	Print out an app's logs
    crashlogs APP           	Print out the logs for an app's crashed instances
    file APP [PATH]         	Print out an app's file contents
    files APP [PATH]        	Examine an app's files
    health APPS...          	Get application health
    stats [APP]             	Display application instance status
    map APP URL             	Add a URL mapping for an app
    unmap APP [URL]         	Remove a URL mapping from an app
    env [APP]               	Show all environment variables set for an app
    set-env APP NAME [VALUE]	Set an environment variable
    unset-env APP NAME      	Remove an environment variable

Services
  services        	List your service instances
  service INSTANCE	Show service instance information

  Management
    create-service [SERVICE] [NAME]	Create a service
    bind-service [INSTANCE] [APP]  	Bind a service instance to an application
    unbind-service [INSTANCE] [APP]	Unbind a service from an application
    delete-service [INSTANCE]      	Delete a service
    tunnel [INSTANCE] [CLIENT]     	Tells you to install tunnel-vmc-plugin

Organizations
  org [ORGANIZATION]       	Show organization information
  orgs                     	List available organizations
  create-org [NAME]        	Create an organization
  delete-org [ORGANIZATION]	Delete an organization

Spaces
  space [SPACE]                     	Show space information
  spaces [ORGANIZATION]             	List spaces in an organization
  create-space [NAME] [ORGANIZATION]	Create a space in an organization
  take-space NAME                   	Switch to a space, creating it if it doesn't exist
  delete-space [SPACE]              	Delete a space and its contents

Routes
  routes              	List routes in a space
  delete-route [ROUTE]	Delete a route
  create-route [URL]  	Create a route

Domains
  domains [ORGANIZATION]	List domains in a space
  delete-domain [DOMAIN]	Delete a domain
  create-domain NAME    	Create a domain
  add-domain NAME       	Add a domain to a space
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
