# chef-openvpn

[![Build Status](https://travis-ci.org/cmur2/chef-openvpn.png)](https://travis-ci.org/cmur2/chef-openvpn)

## Description

A multi-configuration OpenVPN client/server cookbook featuring IPv6 support and easy generation of client configuration files.

## Usage

Include `recipe[openvpn::default]` in your `run_list` and do further configuration via node attributes. To automatically generate client configuration file stubs include `recipe[openvpn::users]`. With `recipe[openvpn::logrotate]` your logs (of all configurations) will be automatically rotated if the logrotate cookbook is present. To setup one or multiple OpenVPN clients use `recipe[openvpn::client]`.

For full, out-of-the-box IPv6 support you will need OpenVPN 2.3 or higher which is not available on older versions of Debian and Ubuntu - therefore and for those who only want more recent OpenVPN packages on their system the `recipe[openvpn::use_community_repos]` registers new APT repositories maintained by the OpenVPN community (needs the apt cookbook).

## Requirements

### Platform

It should work on all OSes that provide a (recent, versions above 2.0) openvpn package.

## Recipes

### default

Configures and starts an OpenVPN server for each configuration (config name => config hash) found in `node["openvpn"]["configs"]`. A configuration may contain several options (most of them being required as long as not stated otherwise) such as:

* config["port"] - port number the server listens on
* config["proto"] - 'udp' or 'tcp'
* config["dev"] - 'tun', 'tap' or a specific device like 'tun0'
* config["mode"] - 'routed' (uses server directive) or 'bridged' (uses server-bridge directive)
* config["remote_host"] - host name that clients can use to reach the server
* config["remote_port"] - port that clients can use to reach the server (may be omitted, defaults to config["port"])
* config["subnet"] - the IPv4 subnet (*don't* use CIDR here) used for VPN addresses in 'routed' mode
* config["subnet6"] - the IPv6 subnet (use CIDR here) used for VPN addresses in 'routed' mode - requires OpenVPN 2.3 or higher
* config["server_ip"] - the server's VPN address in 'bridged' mode
* config["dhcp_start"] - the lower bound for DHCP addresses in 'bridged' mode
* config["dhcp_end"] - the upper bound for DHCP addresses in 'bridged' mode
* config["netmask"] - the VPN internal IPv4 netmask, applies for 'routed' and 'bridged' mode
* config["auth"]["type"] - 'cert', 'cert_passwd' or 'passwd' - combines client certificates with user passwords if enabled
* config["dh_keysize"] - may be omitted, if specified will be the number of bits generated for the Diffie Hellman key file, if missing a cookbook_file has to be provided
* config["file_cookbook"] - may be omitted, if specified will be used as the name of a cookbook where certificates and key file will be loaded from instead of the current cookbook
* config["redirect_gateway"] - may be omitted, if specified and true pushes redirect-gateway option to clients
* config["push_dns_server"] - may be omitted, if specified and true pushes the DNS server from config["push_dns"] to clients
* config["push_dns"] - DNS server to be pushed to clients if enabled
* config["allow_duplicate_cn"] - may be omitted, if specified and true allows duplicate common names of clients
* config["allow_client_to_client"] - may be omitted, if specified and true allows client-to-client traffic

There are no defaults for this attributes so missing specific attributes may lead to errors.

Example node configuration:

```ruby
'openvpn': {
  'community_repo_flavor': 'snapshots',
  'configs': {
    'openvpn6': {
      'port': 1194,
      'proto': 'udp',
      'dev': 'tun',
      'mode': 'routed',
      'remote_host': 'vpn.example.org',
      'subnet': '10.8.0.0',
      'subnet6': '2001:0db8:0:0::0/64',
      'netmask': '255.255.0.0',
      'auth': {
        'type': 'passwd'
      },
      'allow_duplicate_cn': true
    }
  }
}
```

The certificate files needed for the server should be placed in the cookbook's files directory (or via an overlay site-cookbooks directory that leaves the original cookbook untouched) as follows:

* *config_name*-ca.crt - certificate authority (CA) file in .pem format
* *config_name*.crt - local peer's signed certificate in .pem format
* *config_name*.key - local  peer's private key in .pem format
* optional: *config_name*-dh.pem - file containing Diffie Hellman parameters in .pem format (needed only if config["dh_keysize"] is missing)

Each authentication mode requires you to specify your users database in a databag named *config_name*-users (dots transformed to underscores) that contains one item per user (id is the username). A user's password is stored at the 'pass' key.

Example data_bag:

```json
{
    "id": "foo",
    "pass": "secret"
}
```

### users

Generates OpenVPN configuration stub files in a subdirectory of the configuration's directory on the server. All known options will be prefilled but in a client OS-independent manner (e.g. for windows clients some options are missing). Plans are to extend this to even generate Windows-specific or Tunnelblick-specific files.
Next to the configuration file all needed certificates and keys are stored.

This recipe will generate the user's configuration files in the *users* subdirectory of the server configuration directory it belongs to.
It requires a databag named *config_name*-users (dots transformed to underscores) that contains one item per user and the following cookbook files per user:

* *config_name*-ca.crt - server's CA certificate (may/should be present for the server config too)
* *config_name*-*user_name*.crt - client's signed certificate in .pem format
* *config_name*-*user_name*.key - client's private key in .pem format

The **username** comes from the 'name' property of each item if given, else the databag ID (which sufferes from some limitation, e.g. underscores are not allowed) will be used automatically as username.

### client

This works nearly as the default recipe and configures and starts an OpenVPN client for each configuration (client config name => config hash) found in `node["openvpn"]["client_configs"]`. A configuration may contain several options such as:

* config["user_name"] - the user_name the server awaits (used for identifying need cert and key files)
* config["auth"]["type"] - 'cert', 'cert_passwd' or 'passwd' - combines client certificates with user passwords if enabled
* config["file_cookbook"] - may be omitted, if specified will be used as the name of a cookbook where certificates and key file will be loaded from instead of the current cookbook

The certificate files should be placed in the cookbook's files directory (or via an overlay site-cookbooks directory that leaves the original cookbook untouched) as follows:

* *config_name*-*user_name*.conf - configuration file for this client (manually crafted or generated via users recipe)
* *config_name*-ca.crt - server's CA certificate
* *config_name*-*user_name*.crt - client's signed certificate in .pem format
* *config_name*-*user_name*.key - client's private key in .pem format

### use_community_repos

When run on supported platforms (Debian, Ubuntu) adds a new APT repository that uses the OpenVPN community repos. Most times you may choose between the two flavors stable (default) or snapshots (later is needed for OpenVPN 2.3 on Debian Squeeze).

* node["openvpn"]["community_repo_flavor"] - 'stable' or 'snapshots' (default is 'snapshots')

### logrotate

Adds a OpenVPN specific logrotate configuration when logrotate cookbook is found. No attributes needed.

## License

chef-openvpn is licensed under the Apache License, Version 2.0. See LICENSE for more information.
