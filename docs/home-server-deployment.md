# Home server deployment

This deployment is intended for a private LAN realm built from this fork. It
keeps MySQL, logs, generated configuration, and server data under one host path
so updates and a later playerbots migration can be backed up independently of
the Git checkout.

The repository does not contain Blizzard or Ascension client assets. Use only a
client copy you are authorized to use, and never commit client files or secrets.

## 1. Prepare dockerholder

The initial C++ image build is CPU- and memory-intensive. The home Compose file
defaults to four compiler jobs for an 11 GiB VM. Keep at least 20 GiB free for
the Git checkout, build cache, images, database, and downloaded server data.

Run once on the Docker VM:

```sh
sudo install -d -o 1000 -g 1000 \
  /srv/azerothcore/etc \
  /srv/azerothcore/logs \
  /srv/azerothcore/data \
  /srv/azerothcore/backups
sudo install -d /srv/azerothcore/mysql
hostname -I
```

Do not reuse a MySQL directory from a stock AzerothCore installation. The CoA
bootstrap must import its packaged world baseline into a new, empty world
schema before the normal database updater runs.

## 2. Create the Portainer Git stack

In Portainer, create a stack from this Git repository and branch. Set the
Compose path to:

```text
docker-compose.home.yml
```

Add the variables from `home-server.env.example` in Portainer. At minimum,
replace `COA_DB_ROOT_PASSWORD` with a unique password and confirm the VM address
used by `COA_BIND_IP`, `COA_REALM_ADDRESS`, and `COA_REALM_LOCAL_ADDRESS`.

Keep automatic Git redeployment disabled. Pull and rebuild only after reviewing
an upstream sync in this fork.

The first deployment builds the core, verifies and imports the CoA world
baseline, creates the normal auth/character databases, downloads AzerothCore's
server map data, and sets realm id 1 to the configured LAN address. The
`coa-world-bootstrap`, `coa-db-import`, `coa-client-data`,
`coa-ascension-dbc-check`, and `coa-realm-config` containers are expected to
exit successfully; they are one-shot initialization jobs.

## 3. Supply the private client DBCs

The compatibility module additionally requires these three extracted client
tables:

```text
/srv/azerothcore/data/dbc/Ascension/Appearances.dbc
/srv/azerothcore/data/dbc/Ascension/ItemAppearances.dbc
/srv/azerothcore/data/dbc/Ascension/VanityCollection.dbc
```

Copy the matching files from the authorized CoA client-data package into that
directory before deploying the stack. Do not substitute files from another
client revision. The startup check deliberately blocks `coa-worldserver` when
one is absent, empty, or does not match the validated hashes.

For the validated native-v4 client snapshot, all three tables are stored under
`DBFilesClient` in `Data/patch-M.MPQ`:

| File | Records | Record size | SHA256 |
| --- | ---: | ---: | --- |
| `Appearances.dbc` | 42,903 | 68 | `7c7b27fa9e535d7ec7549eb61ef1490ec69b990fa243a2ed36fb6dbf7df118f9` |
| `ItemAppearances.dbc` | 202,932 | 12 | `c2533eaa0c84ccb35e1087b6244e8881f89642385e646a9f7fc6dddf1e6ea434` |
| `VanityCollection.dbc` | 10,764 | 308 | `aae91e8c4966790be090c1a69d124745aca4bfa4a09f43b52f0789667c98d46c` |

These identities belong to this client snapshot. Review and update the guarded
hashes together if a later authorized client version changes one of the tables.

## 4. Prepare a separate Windows client copy

Do not point the live Ascension launcher at the private realm copy because an
updater can replace the local changes. Copy the complete client to a local SSD,
then set `Data/enUS/realmlist.wtf` to the Docker VM address:

```text
set realmlist 192.168.0.36
```

The native v4 `Extensions.dll` must also contain the repository's remote-world
endpoint fix. From PowerShell, check the source DLL first:

```powershell
Get-FileHash 'C:\Games\Conquest-of-Azeroth-Local\Extensions.dll' -Algorithm SHA256
```

The accepted unpatched hash is
`f7b713095aab17a1e376f487290d4b7c4c18931635e4d91136d76db2592be8fa`;
the accepted patched hash is
`9791801053f828d1ccdab1a4c17e64852d3ebe0fa708b91fa3674d0805d15bc8`.
If the file has the unpatched hash, close the client and generate a separate
candidate with `apps/client-compat/patch_world_endpoint.py`. The tool refuses
unknown DLL versions and does not overwrite the source file.

## 5. Create the first account

After `coa-worldserver` reports that it is ready, attach from the Docker VM:

```sh
docker attach coa-worldserver
```

At the `AC>` prompt, create the account and grant realm-wide administrator
access. Use a unique account password, not the MySQL password:

```text
account create admin replace-with-a-different-password
account set gmlevel admin 3 -1
```

Detach without stopping the server by pressing `Ctrl-p`, then `Ctrl-q`.

## Updating and rollback

Before a reviewed rebuild, create a database backup:

```sh
backup="/srv/azerothcore/backups/coa-$(date -u +%Y%m%dT%H%M%SZ).sql"
docker exec coa-database sh -c \
  'exec mysqldump --user=root --password="$MYSQL_ROOT_PASSWORD" \
  --single-transaction --routines --events --all-databases' \
  > "$backup"
```

Record the running fork commit beside the backup. Sync upstream into a branch,
review the changes, then redeploy the Portainer stack. The one-shot bootstrap
will detect the existing world schema and will not replace it; the normal
database updater applies new migrations.

Playerbots is a later core migration, not a module that can safely be enabled on
this ordinary AzerothCore/CoA binary. Keep the database backup, configuration,
logs, and matching client package together when testing a future combined CoA +
Playerbot core. Do not point the persistent production database at an untested
playerbot image.
