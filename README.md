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
        - /configuration/%{fqdn}
        - /configuration/common

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

## Thanks

Heavily based on [etcd-hiera](https://github.com/garethr/hiera-etcd) written by @garethr which was inspired by [hiera-http](https://github.com/crayfishx/hiera-http) from @crayfishx.
Thanks to @mitchellh for writing such wonderful tools and the [API Documentation](http://www.consul.io/docs/agent/http.html)
