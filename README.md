[![Puppet Forge](http://img.shields.io/puppetforge/v/lynxman/hiera_consul.svg)](https://forge.puppetlabs.com/lynxman/hiera_consul)

[consul](http://www.consul.io) is an orchestration mechanism with fault-tolerance based on the gossip protocol and a key/value store that is strongly consistent. Hiera-consul will allow hiera to write to the k/v store for metadata centralisation and harmonisation.

## Configuration

The following hiera.yaml should get you started.

    :backends:
      - consul

    :consul:
      :host: 127.0.0.1
      :port: 8500
      :paths:
        - /v1/kv/configuration/%{fqdn}
        - /v1/kv/configuration/common

## Extra parameters

As this module uses http to talk with Consul API the following parameters are also valid and available

    :consul:
      :host: 127.0.0.1
      :port: 8500
      :use_ssl: false
      :ssl_verify: false
      :ssl_cert: /path/to/cert
      :ssl_key: /path/to/key
      :ssl_ca_cert: /path/to/ca/cert
      :failure: graceful
      :ignore_404: true

## Query the catalog

You can also query the Consul catalog for values by adding catalog resources in your paths, the values will be returned as an array so you will need to parse accordingly.

    :backends:
      - consul

    :consul:
      :host: 127.0.0.1
      :port: 8500
      :paths:
        - /v1/kv/configuration/%{fqdn}
        - /v1/kv/configuration/common
        - /v1/catalog/service
        - /v1/catalog/node

## Helper function

# consul_info

This function will allow you to read information out of a consul Array, as an example here we recover node IPs based on a service:

    $consul_service_array = hiera('rabbitmq',[])
    $mq_cluster_nodes = consul_info($consul_service_array, 'Address')

In this example $mq_cluster_nodes will have a hash with all the IP addresses related to that service

## Thanks

Heavily based on [etcd-hiera](https://github.com/garethr/hiera-etcd) written by @garethr which was inspired by [hiera-http](https://github.com/crayfishx/hiera-http) from @crayfishx.
Thanks to @mitchellh for writing such wonderful tools and the [API Documentation](http://www.consul.io/docs/agent/http.html)
