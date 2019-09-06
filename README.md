[![Gem Version](https://badge.fury.io/rb/vidar.svg)](https://rubygems.org/gems/vidar)
[![Build Status](https://travis-ci.org/RenoFi/vidar.svg?branch=master)](https://travis-ci.org/RenoFi/vidar)

# Vidar

Vidar is a set of docker & k8s deployment tools based on thor gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vidar'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install vidar


#### Requirements :

* multistage `Dockerfile`, with 3 stages defined: `builder`, `runner`, `release`.
* `docker-compose.ci.yml` file with defined services for all 3 stages
* `vidar.yml` file to the project root directory, which following content:

```yml
# docker image name, required
image: gcr.io/renofiinfrastructure/vidar 
# k8s namespace, required
namespace: borrower 
# slack webhook url use to send deploy notifications, optional
slack_webhook_url: https://hooks.slack.com/services/....../....../....../ 
# github name used to conctruct slack notification content, required when slack_webhook_url is set
github: RenoFi/vidar 
# Cluster url, used to conctruct slack notification content.
# Usually it displays k8 workloads filtered to current cluster and namespace. 
# Similar to all other values it may contain references to others using mustache-like interpolation.
# Required when slack_webhook_url is set
cluster_url: "https://console.cloud.google.com/kubernetes/workload?cluster={{cluster_name}}&namespace={{namespace}}" 
# known k8s cluster_names, used to construct regexp to fetch current cluster from kubectl context
# Required when slack_webhook_url is set
cluster_names: "cluster-A|cluster-B" cluster name from kubectl context
# docker-compose file, optional, default value: docker-compose.ci.yml
compose_file: docker-compose.ci.yml
# default_branch, optional, default value: master
default_branch: dev
```

## Usage

Available commands are:

`vidar pull` - pulls existing docker images from repository to levarage docker caching and make build faster

`vidar build` - builds docker images

`vidar cache` - caches intermediate stages

`vidar publish` - publishes docker images

`vidar release` - a set of `pull`, `build`, `cache` and `publish`

`vidar deploy` - deploys/applies release image with `REVISION` tag in given k8s namespace and cluster (unser the hood it's `kubectl set image` command). Before calling the command you must have `kubectl` context set. If you use GCP/GKE simply call `gcloud container clusters get-credentials you-cluser-name --zone=us-east4`. If you have `deploy-hook-template` job defined, it creates `deploy-hook` job with given `REVISION`.

`vidar monitor_deploy_status` - monitors if all containers are up and running, if slack_webhook_url if defined, sends a noficiation (on both failure and success).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/RenoFi/vidar. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

