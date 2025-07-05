# VNC Honeypot in Docker

This is pretty risky to run and it's super obvious it's a honeypot... honestly you probably shouldn't use this. But it's cool!

`./launch.sh` will build the docker image and expose a VNC server on port 5900. Any time someone connects, it records their session to `./recordings` with their IP in the filename.

The container automatically restarts every 10 minutes to avoid becoming a permanent botnet node.

Big ups to [@Xtrato](https://x.com/Xtrato/status/1939222218107445715) for the inspiration.
