# YubiHSB/signatory.io setup

The general docs you want are here:

[https://signatory.io/docs/yubihsm](https://signatory.io/docs/yubihsm)


## Installation

You’ll install two things: the yubikey services, and the signatory. The signatory docs talk about using docker, but in the end I did not do that, it was easier just to build and install signatory locally, particularly as their instructions don’t seem to work with the docker container they provide.


### Prep:

You will want to install the following packages for the yubikey tools:

```
$ sudo apt install libpcsclite1 libusb-1.0-0 libedit2
```

You will want to install the following packages to build signatory:

```
$ sudo apt install make gcc
```

You will want to install Go to build signatory. I did that by [downloading the latest binaries](https://go.dev/dl/) and followed the [instructions here](https://go.dev/doc/install) - though these can be summarised down to:

```
$ rm -rf /usr/local/go && tar -C /usr/local -xzf go1.19.3.linux-amd64.tar.gz
```

### Install the Yubikey binaries:

You’ll need to install the yubikey binaries from here:

[https://developers.yubico.com/YubiHSM2/Releases/](https://developers.yubico.com/YubiHSM2/Releases/)

It doesn’t seem to have an INSTALL file, which is annoying. The tar.gz you get has a bunch of Debs in it. In the current release at time of writing, you want to install all the yubikey Debian packages except `libyubihsm-dev_2.3.2_amd64.deb`, which will conflict with the non-dev version. The Signatory docs suggest a smaller subset, but installing them all installs things like the udev rule and systemd script which you’ll want:

* /usr/lib/udev/rules.d/70-yubihsm-connector.rules
* /usr/lib/systemd/system/yubihsm-connector.service.

It also sets up the user/group for running the services. You can play with the config file in `/etc/yubihsm-connector.yaml` - though currently I have left it as is. In particular note that the connector will run a service on http://localhost:12345 - you don’t want to open that up beyond localhost, but you may wish to change the port.

Once all that is done you want to set the YubiHSM service to run on boot:

```
$ sudo systemctl enable yubihsm-connector
Created symlink /etc/systemd/system/multi-user.target.wants/yubihsm-connector.service → /lib/systemd/system/yubihsm-connector.service.
```

Then either start the service manually using the same command with start rather than enable, or reboot to convince yourself it’ll actually start on boot.

### Install the signatory binaries

Ignore the docker bits in the signatory.io docs and just install go, gcc, and make, and then build signatory:

```
$ git clone https://github.com/ecadlabs/signatory.git
$ cd signatory
$ make
$ sudo cp signatory signatory-cli /usr/local/bin
```

The yubihsm tools created a user when they were installed, but we need to do that by hand for signatory:

```$  sudo useradd  -d /nonexistent -s /usr/sbin/nologin signatory```

If you’re going to be playing around with this then you should add yourself to the signatory group:

```$ sudo usermod -aG signatory [YOUR USER NAME HERE]```

Then make a directory with the correct permissions to let you use things:

```
$ sudo mkdir /var/lib/signatory
$ sudo chown signatory:signatory /var/lib/signatory
$ cudo chmod 775 /var/lib/signatory
```

## Configuration/Setup

### Setting up signatory

Tell signatory to use the yubikey, by setting `/etc/signatory.yaml` to the following:

```
server:
  address: localhost:6732
  utility_address: localhost:9583

vaults:
  yubi:
	driver: yubihsm
	config:
	  address: localhost:12345 # Address for the yubihsm-connector
	  password: password
	  auth_key_id: 1
```

You’ll need to update this once you’ve added keys to specify permissions for each key accessed through the service.

## Installing a key for signing

Now you can install a key using signatory-cli. Here I’ve blanked out the secret key, but the easy thing to do is just generate a key with tezos-client, and then look in `$HOME/.tezos-client/secret-keys` :)

```
$ signatory-cli list
INFO[0000] Initializing vault                            vault=yubihsm vault_name=yubi
ERRO[0000] No valid keys found in the vault yubi

$ signatory-cli import --vault yubi edskXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
INFO[0000] Initializing vault                            vault=yubihsm vault_name=yubi
INFO[0000] Requesting import operation                   pkh=tz1YYBnLs471SKKReLn8nV47Tqh9VDgPoE7F vault=YubiHSM vault_name="localhost:12345/1"
INFO[0000] Successfully imported                         key_id=91e5 pkh=tz1YYBnLs471SKKReLn8nV47Tqh9VDgPoE7F vault=YubiHSM vault_name="localhost:12345/1"

$ signatory-cli list
INFO[0000] Initializing vault                            vault=yubihsm vault_name=yubi
Public Key Hash:    tz1YYBnLs471SKKReLn8nV47Tqh9VDgPoE7F
Vault:              YubiHSM
ID:                 91e5
Active:             false
```

Now that you’ve added a key you’ll need to go back and modify `/etc/sigantory.yaml` to specify permissions. Please ensure these match what’s used in the CI integration tests! Also note you need to match the key to the one you install.

```
server:
  address: localhost:6732
  utility_address: localhost:9583

vaults:
  yubi:
	driver: yubihsm
	config:
	  address: localhost:12345 # Address for the yubihsm-connector
	  password: password
	  auth_key_id: 1

# List enabled public keys hashes here
tezos:
  # Default policy allows "block" and "endorsement" operations
  tz1YYBnLs471SKKReLn8nV47Tqh9VDgPoE7F:
	log_payloads: true
	allow:
	  block: []
	  endorsement: []
	  generic:
		- endorsement
		- reveal
		- transaction
```

### Set signatory service up to run

This is a final install stage - now that you have signatory configured, add a systemd script to get it to run on boot:

```
$ cat /usr/lib/systemd/system/signatory.service
[Unit]
Description=Signatory Tezos signing service
Documentation=https://signatory.io/
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Restart=on-abnormal

; User and group the process will run as.
User=signatory
Group=signatory

ExecStart=/usr/local/bin/signatory serve -c /etc/signatory.yaml

; Use private /tmp and /var/tmp, which are discarded after caddy stops.
PrivateTmp=true
; Hide /home, /root, and /run/user. Nobody will steal your SSH-keys.
ProtectHome=true
; Make /usr, /boot, /etc and possibly some more folders read-only.
ProtectSystem=full

[Install]
WantedBy=multi-user.target
```

And as before:

```
$ sudo systemctl enable signatory
$ sudo systemctl start signatory
```

You should now be able to sign something:

```
$ curl -XPOST -d '"027a06a770e6cebe5b3e39483a13ac35f998d650e8b864696e31520922c7242b88c8d2ac55000003eb6d"' http://localhost:6732/keys/tz1YYBnLs471SKKReLn8nV47Tqh9VDgPoE7F
{"signature":"siggciAA1KQuabtoWsa4SFMPMBpvPx2CbfqGPuc4CuP4UFMpyQaJWT4MrFsbe9PqxFNkb7c31qvncjXkHZRFo2HtjPp6UTZJ"}
```

