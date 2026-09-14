# Home-server deployment

This deployment targets the Dockerholder Ubuntu VM and keeps the database and SOAP
interfaces off the network. Only the WoW authentication and world ports are published.
Do not forward those ports through the router. Remote players should use a private VPN.

The source branch is intentionally separate from `main`:

- `main` stays easy to fast-forward from `jealous-sound/azerothcore-wotlk-coa`.
- `home-server` is the branch Portainer deploys.
- Upstream updates do not reach the live server until they are reviewed, merged into
  `home-server`, backed up, rebuilt, and tested.

## 1. Check the Docker host

Run these on Dockerholder before deploying:

```sh
nproc
free -h
df -h /var/lib/docker /srv
docker version
docker compose version
```

The first source build is CPU and memory intensive and needs substantial free disk space.

## 2. Prepare persistent directories

```sh
sudo install -d -m 0750 -o 999 -g 999 /srv/azerothcore-coa/database
sudo install -d -m 0750 -o 1000 -g 1000 \
  /srv/azerothcore-coa/etc \
  /srv/azerothcore-coa/logs \
  /srv/azerothcore-coa/client-data \
  /srv/azerothcore-coa/backups
```

Change the IDs if `DOCKER_USER_ID` or `DOCKER_GROUP_ID` will not be 1000.

## 3. Create the Portainer Git stack

Use these settings:

- Repository URL: `https://github.com/paintbeat/azerothcore-wotlk-coa`
- Repository reference: `refs/heads/home-server`
- Compose path: `deploy/home-server/docker-compose.yml`

Copy the values from `home-server.env.example` into Portainer. Replace the database
password with a unique random value. Do not set `COMPOSE_PROFILES` yet.

The first deployment prepares MySQL, imports the versioned CoA world baseline, creates
the authentication and character schemas, and downloads standard AzerothCore server
data. The one-shot containers should exit with code 0. Only `coa-database` remains
running at this stage.

## 4. Add the matching CoA server data

The custom client requires data that is not distributed by ordinary AzerothCore.
Before starting either game-server container, copy the matching server-side data from
the authorized CoA repack into:

```text
/srv/azerothcore-coa/client-data
```

At minimum, verify that the resulting tree contains the normal `dbc`, `maps`,
`mmaps`, and `vmaps` directories plus:

```text
/srv/azerothcore-coa/client-data/dbc/Ascension/Appearances.dbc
/srv/azerothcore-coa/client-data/dbc/Ascension/ItemAppearances.dbc
/srv/azerothcore-coa/client-data/dbc/Ascension/VanityCollection.dbc
```

The exact copy command depends on the layout of the repack. Inspect that archive before
copying files or enabling the server profile.

## 5. Start the realm

After the data check passes, add this Portainer stack variable and redeploy:

```text
COMPOSE_PROFILES=server
```

This enables `coa-authserver` and `coa-worldserver`. The stack publishes TCP 3724
and TCP 8085. MySQL remains internal to the Compose network, and SOAP stays disabled.

Update the `acore_auth.realmlist` row so its address is reachable by every intended
client. For the initial LAN setup, use Dockerholder's address, `192.168.0.36`. If all
clients later use a private VPN, change this to the Dockerholder VPN DNS name or VPN
address.

## 6. Client compatibility

Use the matching native CoA v4 client from the repack. A client on another computer is
a remote client from the server's perspective, even on the same LAN. This deployment
therefore enables the repository's remote Ascension compatibility mode.

The repository's `apps/client-compat/README.md` describes the required
`Extensions.dll` hash check and world-endpoint patch. Do not apply the patch to an
unknown DLL. Set the client's locale-specific `realmlist.wtf` to the same address
stored in the server's `realmlist` table.

## 7. Back up before every update

Create an all-database dump while MySQL is running:

```sh
docker exec coa-database sh -c \
  'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --events --all-databases' \
  | gzip > "/srv/azerothcore-coa/backups/coa-$(date +%F-%H%M).sql.gz"
```

Also retain the matching client-data directory and the exact Git commit deployed.

## 8. Controlled updates

1. Review the upstream commits and open issues.
2. Fast-forward the fork's `main` branch.
3. Merge `main` into `home-server`.
4. Back up the database and record the currently deployed commit.
5. Rebuild and redeploy the Portainer stack.
6. Verify authentication, character login, and gameplay before accepting the update.

Do not automatically update these images with Watchtower. They are locally built from
the selected Git commit and must move together with their database migrations.

## Future playerbots

The maintained `mod-playerbots` project requires its own customized AzerothCore
`Playerbot` branch; installing only the module into this CoA core is unsupported.
Keep playerbots out of the initial build. A future combined branch must reconcile the
Playerbot core changes with the CoA core and `mod-ascension-compat`, then be tested
against a restored copy of the database before the live stack is changed.
