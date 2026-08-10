<!-- Maintained manually; content mirrors readme-vars.yml -->

[![GitHub Stars](https://img.shields.io/github/stars/wOvAN/docker-amneziawg.svg?color=94398d&labelColor=555555&logoColor=ffffff&style=for-the-badge&logo=github)](https://github.com/wOvAN/docker-amneziawg)
[![GitHub Release](https://img.shields.io/github/release/wOvAN/docker-amneziawg.svg?color=94398d&labelColor=555555&logoColor=ffffff&style=for-the-badge&logo=github)](https://github.com/wOvAN/docker-amneziawg/releases)
[![Docker Pulls](https://img.shields.io/docker/pulls/wovan/amneziawg.svg?color=94398d&labelColor=555555&logoColor=ffffff&style=for-the-badge&label=pulls&logo=docker)](https://hub.docker.com/r/wovan/amneziawg)
[![Docker Stars](https://img.shields.io/docker/stars/wovan/amneziawg.svg?color=94398d&labelColor=555555&logoColor=ffffff&style=for-the-badge&label=stars&logo=docker)](https://hub.docker.com/r/wovan/amneziawg)

**This is a fork of [linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard) with the VPN engine replaced by [AmneziaWG](https://github.com/amnezia-vpn/amneziawg-go) (AWG 3.0)** — the management approach (env vars, templates, peer/QR flow, s6 services) is unchanged, only the tooling differs (`awg`/`awg-quick`/`amneziawg-go` instead of `wg`/`wg-quick`) and generated confs carry AWG 3.0 obfuscation parameters.

[AmneziaWG](https://github.com/amnezia-vpn/amneziawg-go) is a contemporary version of the WireGuard protocol, a fork of WireGuard-Go that offers protection against detection by Deep Packet Inspection (DPI) systems. It retains the simplified architecture and high performance of the original while adding advanced obfuscation methods (junk packets, message padding, header protection, content padding and randomized timings), allowing its traffic to blend seamlessly with regular internet traffic.

[![amneziawg](https://avatars.githubusercontent.com/u/74861536?v=4)](https://github.com/amnezia-vpn/amneziawg-go)

## Supported Architectures

We utilise the docker manifest for multi-platform awareness. More information is available from docker [here](https://distribution.github.io/distribution/spec/manifest-v2-2/#manifest-list).

Simply pulling `wovan/amneziawg:latest` should retrieve the correct image for your arch, but you can also pull specific arch images via tags.

The architectures supported by this image are:

| Architecture | Available | Tag |
| :----: | :----: | ---- |
| x86-64 | ✅ | amd64-\<version tag\> |
| arm64 | ✅ | arm64v8-\<version tag\> |

## Application Setup

During container start, it will first check if the amneziawg kernel module is already installed and loaded. If it is not, the container will fall back to the amneziawg-go userspace implementation, which requires the `/dev/net/tun` device to be passed through to the container (`--device=/dev/net/tun`). The amneziawg kernel module is not built into stock kernels, so most users will run on the userspace implementation.

This image generates server and peer configs with AmneziaWG 3.0 obfuscation parameters (junk packets `Jc`/`Jmin`/`Jmax`, message padding `S1`-`S4`, magic headers `H1`-`H4`, `HeaderProtectionKey`, content padding and randomized rekey/keepalive timings) which are randomly generated once per server and shared between the server and peer configs, just like the server keys. The generated peer configs can be imported into the Amnezia VPN clients (desktop, mobile, iOS).

This can be run as a server or a client, based on the parameters used.

## Note on iptables

Some hosts may not load the iptables kernel modules by default. In order for the container to be able to load them, you need to assign the `SYS_MODULE` capability and add the optional `/lib/modules` volume mount. Alternatively you can `modprobe` them from the host before starting the container.

## Server Mode

If the environment variable `PEERS` is set to a number or a list of strings separated by comma, the container will run in server mode and the necessary server and peer/client confs will be generated. The peer/client config qr codes will be output in the docker log if `LOG_CONFS` is set to `true`. They will also be saved in text and png format under `/config/peerX` in case `PEERS` is a variable and an integer or `/config/peer_X` in case a list of names was provided instead of an integer.

Variables `SERVERURL`, `SERVERPORT`, `INTERNAL_SUBNET`, `PEERDNS`, `INTERFACE`, `ALLOWEDIPS` and `PERSISTENTKEEPALIVE_PEERS` are optional variables used for server mode. Any changes to these environment variables will trigger regeneration of server and peer confs. Peer/client confs will be recreated with existing private/public keys. Delete the peer folders for the keys to be recreated along with the confs.

To add more peers/clients later on, you increment the `PEERS` environment variable or add more elements to the list and recreate the container.

To display the QR codes of active peers again, you can use the following command and list the peer numbers as arguments: `docker exec -it amneziawg /app/show-peer 1 4 5` or `docker exec -it amneziawg /app/show-peer myPC myPhone myTablet` (Keep in mind that the QR codes are also stored as PNGs in the config folder).

The templates used for server and peer confs are saved under `/config/templates`. Advanced users can modify these templates and force conf generation by deleting `/config/wg_confs/wg0.conf` and restarting the container.

The AmneziaWG 3.0 obfuscation parameters are randomly generated once per server (along with the server keys) and stored in `/config/server/awgparams`. Both templates reference this file with a `$(cat /config/server/awgparams)` line, so the same parameters end up in the server conf and all peer confs (S1-S4, H1-H4 and HeaderProtectionKey must match between server and clients). Advanced users can replace that line in a template with explicit values, or edit the awgparams file and delete wg0.conf to regenerate the confs.

The container managed server conf is hardcoded to `wg0.conf`. However, the users can add additional tunnel config files with `.conf` extensions into `/config/wg_confs/` and the container will attempt to start them all in alphabetical order. If any one of the tunnels fail, they will all be stopped and the default route will be deleted, requiring user intervention to fix the invalid conf and a container restart.

## Client Mode

Do not set the `PEERS` environment variable. Drop your client conf(s) into the config folder as `/config/wg_confs/<tunnel name>.conf` and start the container. If there are multiple tunnel configs, the container will attempt to start them all in alphabetical order. If any one of the tunnels fail, they will all be stopped and the default route will be deleted, requiring user intervention to fix the invalid conf and a container restart.

If you get IPv6 related errors in the log and connection cannot be established, edit the `AllowedIPs` line in your peer/client wg0.conf to include only `0.0.0.0/0` and not `::/0`; and restart the container.

## Road warriors, roaming and returning home

If you plan to use AmneziaWG both remotely and locally, say on your mobile phone, you will need to consider routing. Most firewalls will not route ports forwarded on your WAN interface correctly to the LAN out of the box. This means that when you return home, even though you can see the AmneziaWG server, the return packets will probably get lost.

This is not an AmneziaWG specific issue and the two generally accepted solutions are NAT reflection (setting your edge router/firewall up in such a way as it translates internal packets correctly) or split horizon DNS (setting your internal DNS to return the private rather than public IP when connecting locally).

Both of these approaches have positives and negatives however their setup is out of scope for this document as everyone's network layout and equipment will be different.

## Maintaining local access to attached services

** Note: This is not a supported configuration by Linuxserver.io - use at your own risk.

When routing via AmneziaWG from another container using the `service` option in docker, you might lose access to the containers webUI locally. To avoid this, exclude the docker subnet from being routed via AmneziaWG by modifying your `wg0.conf` like so (modifying the subnets as you require):

  ```ini
  [Interface]
  PrivateKey = <private key>
  Address = 9.8.7.6/32
  DNS = 8.8.8.8
  PostUp = DROUTE=$(ip route | grep default | awk '{print $3}'); HOMENET=192.168.0.0/16; HOMENET2=10.0.0.0/8; HOMENET3=172.16.0.0/12; ip route add $HOMENET3 via $DROUTE;ip route add $HOMENET2 via $DROUTE; ip route add $HOMENET via $DROUTE;iptables -I OUTPUT -d $HOMENET -j ACCEPT;iptables -A OUTPUT -d $HOMENET2 -j ACCEPT; iptables -A OUTPUT -d $HOMENET3 -j ACCEPT;  iptables -A OUTPUT ! -o %i -m mark ! --mark $(awg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
  PreDown = DROUTE=$(ip route | grep default | awk '{print $3}'); HOMENET=192.168.0.0/16; HOMENET2=10.0.0.0/8; HOMENET3=172.16.0.0/12; ip route del $HOMENET3 via $DROUTE;ip route del $HOMENET2 via $DROUTE; ip route del $HOMENET via $DROUTE; iptables -D OUTPUT ! -o %i -m mark ! --mark $(awg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT; iptables -D OUTPUT -d $HOMENET -j ACCEPT; iptables -D OUTPUT -d $HOMENET2 -j ACCEPT; iptables -D OUTPUT -d $HOMENET3 -j ACCEPT
  ```

## Site-to-site VPN

** Note: This is not a supported configuration by Linuxserver.io - use at your own risk.

Site-to-site VPN in server mode requires customizing the `AllowedIPs` statement for a specific peer in `wg0.conf`. Since `wg0.conf` is autogenerated when server vars are changed, it is not recommended to edit it manually.

In order to customize the `AllowedIPs` statement for a specific peer in `wg0.conf`, you can set an env var `SERVER_ALLOWEDIPS_PEER_<peer name or number>` to the additional subnets you'd like to add, comma separated and excluding the peer IP (ie. `"192.168.1.0/24,192.168.2.0/24"`). Replace `<peer name or number>` with either the name or number of a peer (whichever is used in the `PEERS` var).

For instance `SERVER_ALLOWEDIPS_PEER_laptop="192.168.1.0/24,192.168.2.0/24"` will result in the wg0.conf entry `AllowedIPs = 10.13.13.2,192.168.1.0/24,192.168.2.0/24` for the peer named `laptop`.

Keep in mind that this var will only be considered when the confs are regenerated. Adding this var for an existing peer won't force a regeneration. You can delete wg0.conf and restart the container to force regeneration if necessary.

Don't forget to set the necessary POSTUP and POSTDOWN rules in your client's peer conf for lan access.

## Read-Only Operation

This image can be run with a read-only container filesystem. For details please [read the docs](https://docs.linuxserver.io/misc/read-only/).

### Caveats

* Not supported in client mode.

## Usage

To help you get started creating a container from this image you can either use docker-compose or the docker cli.

>[!NOTE]
>Unless a parameter is flagged as 'optional', it is *mandatory* and a value must be provided.

### docker-compose (recommended, [click here for more info](https://docs.linuxserver.io/general/docker-compose))

```yaml
---
services:
  amneziawg:
    image: wovan/amneziawg:latest
    container_name: amneziawg
    cap_add:
      - NET_ADMIN
      - SYS_MODULE #optional
    devices:
      - /dev/net/tun:/dev/net/tun #required for userspace fallback (no kernel module)
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - SERVERURL=vpn.example.com #optional
      - SERVERPORT=51820 #optional
      - PEERS=1 #optional
      - PEERDNS=auto #optional
      - INTERNAL_SUBNET=10.13.13.0 #optional
      - ALLOWEDIPS=0.0.0.0/0 #optional
      - PERSISTENTKEEPALIVE_PEERS= #optional
      - LOG_CONFS=true #optional
    volumes:
      - /path/to/amneziawg/config:/config
      - /lib/modules:/lib/modules #optional
    ports:
      - 51820:51820/udp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
```

### docker cli ([click here for more info](https://docs.docker.com/engine/reference/commandline/cli/))

```bash
docker run -d \
  --name=amneziawg \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE `#optional` \
  --device=/dev/net/tun:/dev/net/tun `#required for userspace fallback (no kernel module)` \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -e SERVERURL=vpn.example.com `#optional` \
  -e SERVERPORT=51820 `#optional` \
  -e PEERS=1 `#optional` \
  -e PEERDNS=auto `#optional` \
  -e INTERNAL_SUBNET=10.13.13.0 `#optional` \
  -e ALLOWEDIPS=0.0.0.0/0 `#optional` \
  -e PERSISTENTKEEPALIVE_PEERS= `#optional` \
  -e LOG_CONFS=true `#optional` \
  -p 51820:51820/udp \
  -v /path/to/amneziawg/config:/config \
  -v /lib/modules:/lib/modules `#optional` \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  wovan/amneziawg:latest
```

## Parameters

Containers are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container.

| Parameter | Function |
| :----: | --- |
| `-p 51820:51820/udp` | amneziawg port |
| `-e PUID=1000` | for UserID - see below for explanation |
| `-e PGID=1000` | for GroupID - see below for explanation |
| `-e TZ=Etc/UTC` | specify a timezone to use, see this [list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List). |
| `-e SERVERURL=vpn.example.com` | External IP or domain name for docker host. Used in server mode. If set to `auto`, the container will try to determine and set the external IP automatically |
| `-e SERVERPORT=51820` | External port for docker host. Used in server mode. |
| `-e PEERS=1` | Number of peers to create confs for. Required for server mode. Can also be a list of names: `myPC,myPhone,myTablet` (alphanumeric only) |
| `-e PEERDNS=auto` | DNS server set in peer/client configs (can be set as `8.8.8.8`). Used in server mode. Defaults to `auto`, which uses docker host's DNS via included CoreDNS forward. |
| `-e INTERNAL_SUBNET=10.13.13.0` | Internal subnet for the amneziawg and server and peers (only change if it clashes). Used in server mode. |
| `-e ALLOWEDIPS=0.0.0.0/0` | The IPs/Ranges that the peers will be able to reach using the VPN connection. If not specified the default value is: '0.0.0.0/0, ::0/0' This will cause ALL traffic to route through the VPN, if you want split tunneling, set this to only the IPs you would like to use the tunnel AND the ip of the server's awg ip, such as 10.13.13.1. |
| `-e PERSISTENTKEEPALIVE_PEERS=` | Set to `all` or a list of comma separated peers (ie. `1,4,laptop`) for the amneziawg server to send keepalive packets to listed peers every 25 seconds. Useful if server is accessed via domain name and has dynamic IP. Used only in server mode. |
| `-e LOG_CONFS=true` | Generated QR codes will be displayed in the docker log. Set to `false` to skip log output. |
| `-v /config` | Contains all relevant configuration files. |
| `-v /lib/modules` | Path to host kernel module for situations where it's not already loaded. |
| `--sysctl=` | Required for client mode. |
| `--read-only=true` | Run container with a read-only filesystem. Please [read the docs](https://docs.linuxserver.io/misc/read-only/). |
| `--cap-add=NET_ADMIN` | Neccessary for AmneziaWG to create its VPN interface. |
| `--cap-add=SYS_MODULE` | Neccessary for loading AmneziaWG kernel module if it's not already loaded. |

### Portainer notice

This image utilises `cap_add` or `sysctl` to work properly. This is not implemented properly in some versions of Portainer, thus this image may not work if deployed through Portainer.

## Environment variables from files (Docker secrets)

You can set any environment variable from a file by using a special prepend `FILE__`.

As an example:

```bash
-e FILE__MYVAR=/run/secrets/mysecretvariable
```

Will set the environment variable `MYVAR` based on the contents of the `/run/secrets/mysecretvariable` file.

## Umask for running applications

For all of our images we provide the ability to override the default umask settings for services started within the containers using the optional `-e UMASK=022` setting.
Keep in mind umask is not chmod it subtracts from permissions based on it's value it does not add. Please read up [here](https://en.wikipedia.org/wiki/Umask) before asking for support.

## User / Group Identifiers

When using volumes (`-v` flags), permissions issues can arise between the host OS and the container, we avoid this issue by allowing you to specify the user `PUID` and group `PGID`.

Ensure any volume directories on the host are owned by the same user you specify and any permissions issues will vanish like magic.

In this instance `PUID=1000` and `PGID=1000`, to find yours use `id your_user` as below:

```bash
id your_user
```

Example output:

```text
uid=1000(your_user) gid=1000(your_user) groups=1000(your_user)
```

## Support Info

* Shell access whilst the container is running:

    ```bash
    docker exec -it amneziawg /bin/bash
    ```

* To monitor the logs of the container in realtime:

    ```bash
    docker logs -f amneziawg
    ```

* Container version number:

    ```bash
    docker inspect -f '{{ index .Config.Labels "build_version" }}' amneziawg
    ```

* Image version number:

    ```bash
    docker inspect -f '{{ index .Config.Labels "build_version" }}' wovan/amneziawg:latest
    ```

## Updating Info

The image is static and versioned, and requires an image update and container recreation to update the app inside. We do not recommend or support updating apps inside the container. Please consult the [Application Setup](#application-setup) section above to see if it is recommended for the image.

Below are the instructions for updating containers:

### Via Docker Compose

* Update images:
    * All images:

        ```bash
        docker-compose pull
        ```

    * Single image:

        ```bash
        docker-compose pull amneziawg
        ```

* Update containers:
    * All containers:

        ```bash
        docker-compose up -d
        ```

    * Single container:

        ```bash
        docker-compose up -d amneziawg
        ```

* You can also remove the old dangling images:

    ```bash
    docker image prune
    ```

### Via Docker Run

* Update the image:

    ```bash
    docker pull wovan/amneziawg:latest
    ```

* Stop the running container:

    ```bash
    docker stop amneziawg
    ```

* Delete the container:

    ```bash
    docker rm amneziawg
    ```

* Recreate a new container with the same docker run parameters as instructed above (if mapped correctly to a host folder, your `/config` folder and settings will be preserved)
* You can also remove the old dangling images:

    ```bash
    docker image prune
    ```

### Image Update Notifications - Diun (Docker Image Update Notifier)

>[!TIP]
>We recommend [Diun](https://crazymax.dev/diun/) for update notifications. Other tools that automatically update containers unattended are not recommended or supported.

## Building locally

If you want to make local modifications to these images for development purposes or just to customize the logic:

```bash
git clone https://github.com/wOvAN/docker-amneziawg.git
cd docker-amneziawg
docker build \
  --no-cache \
  --pull \
  -t wovan/amneziawg:latest .
```

The ARM variants can be built on x86_64 hardware and vice versa using `lscr.io/linuxserver/qemu-static`

```bash
docker run --rm --privileged lscr.io/linuxserver/qemu-static --reset
```

Once registered you can define the dockerfile to use with `-f Dockerfile.aarch64`.

## Versions

* **08.08.26:** - **Potentially Breaking Change:** Replace WireGuard with AmneziaWG (AWG 3.0). The image now ships `awg`/`awg-quick` and the `amneziawg-go` userspace implementation instead of wireguard-tools, and falls back to userspace mode when the amneziawg kernel module is not available (requires `/dev/net/tun`). Generated server and peer confs now include AWG 3.0 obfuscation parameters (Jc/Jmin/Jmax, S1-S4, H1-H4, HeaderProtectionKey, content padding, timings) generated once per server and stored in `/config/server/awgparams`. Existing configs are migrated automatically on first start; peer confs are compatible with the Amnezia VPN clients.
* **05.07.26:** - Rebase to Alpine 3.24.
* **24.01.26:** - Rebase to Alpine 3.23 again as openresolv alpine 3.23 package has now been updated.
* **22.01.26:** - Revert to Alpine 3.22 due to resolvconf bug.
* **04.01.26:** - Rebase to Alpine 3.23.
* **15.07.25:** - Rebase to Alpine 3.22. Remove iptables-legacy shim.
* **01.01.25:** - Deprecate legacy branch.
* **20.12.24:** - Rebase to Alpine 3.21.
* **13.08.24:** - Add `errors` plugin to default Corefile.
* **23.07.24:** - Install kmod from alpine repository.
* **24.05.24:** - Rebase to Alpine 3.20, install wireguard-tools from Alpine repo.
* **10.03.24:** - Use iptables-legacy on Alpine 3.19.
* **05.03.24:** - Rebase master to Alpine 3.19.
* **03.10.23:** - **Potentially Breaking Change:** Support for multiple interfaces added. Wireguard confs moved to `/config/wg_confs/`. Any file with a `.conf` extension in that folder will be treated as a live tunnel config and will be attempted to start. If any of the tunnels fail, all tunnels will be stopped. Tunnels are started in alphabetical order. Managed server conf will continue to be hardcoded to `wg0.conf`.
* **28.06.23:** - Rebase master to Alpine 3.18 again.
* **26.06.23:** - Revert master to Alpine 3.17, due to issue with openresolv.
* **24.06.23:** - Rebase master to Alpine 3.18, deprecate armhf as per [https://www.linuxserver.io/armhf](https://www.linuxserver.io/armhf).
* **26.04.23:** - Rework branches. Swap alpine and ubuntu builds.
* **29.01.23:** - Rebase to alpine 3.17.
* **10.01.23:** - Add new var to add `PersistentKeepalive` to server config for select peers to survive server IP changes when domain name is used.
* **26.10.22:** - Better handle unsupported peer names. Improve logging.
* **12.10.22:** - Add Alpine branch. Optimize wg and coredns services.
* **04.10.22:** - Rebase to Jammy. Upgrade to s6v3.
* **16.05.22:** - Improve NAT handling in server mode when multiple ethernet devices are present.
* **23.04.22:** - Add pre-shared key support. Automatically added to all new peer confs generated, existing ones are left without to ensure no breaking changes.
* **10.04.22:** - Rebase to Ubuntu Focal. Add `LOG_CONFS` env var. Remove deprecated `add-peer` command.
* **28.10.21:** - Add site-to-site vpn support.
* **11.02.21:** - Fix bug related to changing internal subnet and named peer confs not updating.
* **06.10.20:** - Disable CoreDNS in client mode, or if port 53 is already in use in server mode.
* **04.10.20:** - Allow to specify a list of names as PEERS and add ALLOWEDIPS environment variable. Also, add peer name/id to each one of the peer sections in wg0.conf. Important: Existing users need to delete `/config/templates/peer.conf` and restart
* **27.09.20:** - Cleaning service binding example to have accurate PreDown script.
* **06.08.20:** - Replace resolvconf with openresolv due to dns issues when a client based on this image is connected to a server also based on this image. Add IPv6 info to readme. Display kernel version in logs.
* **29.07.20:** - Update Coredns config to detect dns loops (existing users need to delete `/config/coredns/Corefile` and restart).
* **27.07.20:** - Update Coredns config to prevent issues with non-user-defined bridge networks (existing users need to delete `/config/coredns/Corefile` and restart).
* **05.07.20:** - Add Debian updates and security repos for headers.
* **25.06.20:** - Simplify module tests, prevent iptables issues from resulting in false negatives.
* **19.06.20:** - Add support for Ubuntu Focal (20.04) kernels. Compile wireguard tools and kernel module instead of using the ubuntu packages. Make module install optional. Improve verbosity in logs.
* **29.05.20:** - Add support for 64bit raspbian.
* **28.04.20:** - Add Buster/Stretch backports repos for Debian. Tested with OMV 5 and OMV 4 (on kernel 4.19.0-0.bpo.8-amd64).
* **20.04.20:** - Fix typo in client mode conf existence check.
* **13.04.20:** - Fix bug that forced conf recreation on every start.
* **08.04.20:** - Add arm32/64 builds and enable multi-arch (rpi4 with ubuntu and raspbian buster tested). Add CoreDNS for `PEERDNS=auto` setting. Update the `add-peer`/`show-peer` scripts to utilize the templates and the `INTERNAL_SUBNET` var (previously missed, oops).
* **05.04.20:** - Add `INTERNAL_SUBNET` variable to prevent subnet clashes. Add templates for server and peer confs.
* **01.04.20:** - Add `show-peer` script and include info on host installed headers.
* **31.03.20:** - Initial Release.
