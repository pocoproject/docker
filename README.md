Docker repository, for poco builds in docker containers.

Prerequisites:

- docker
- docker-compose

Usage example:
```
./configure --minimal --config=Linux-clang --compiler-version=4.0 --branch=develop
Configured for Linux-clang
./run
```
Configure works in a similar fashion like the POCO configure script (in fact, it is
a modified/extended version thereof). Curently, only gcc and clang on linux are supported.

The above commands will emit proper `config.make` and `config.build` files,
then run the build inside a ubuntu-based container.

Output from the build can be viewed in two ways:

1) `docker logs -f [container_id]`
2) `tail -F out/poco-develop-clang-4.0-Linux-clang.build.out`

Docker logs will, obviously, be destroyed when the container is destroyed.
The logs in `./out` directory, will however, persist.

Source code is checked from github (into `./src` directory on the host filesystem),
switched to indicated branch (`develop` is default) prior to buiding and runing tests.

Once created, container can be stopped/started/restarted/destroyed.:

```
./run [start|stop|restart|down]
```

Container can also be [prevented from exiting](https://github.com/pocoproject/docker/blob/master/entrypoint-baseimage.sh#L90-L96) after all is done, so it is possible to exec into it and try various things:

```
docker exec -it [container_id] bash
```
