# VNC Honeypot in Docker

### __Warning! Don't run this on systems you care about! This is a very poorly isolated honeypot, and it doesn't take a ton of work to break out. This is good (?) for throwaway servers you reimage afterwards. Exfiltrate recordings with care!__

This Docker image contains the bare bones of a Xfce4 and a VNC server. `supervisord` manages the X environment, VNC server, and a script that listens for established port 5900 connections then starts an `ffmpeg` recording and dumps a video of the session to a folder in the container (ideally copied to safety on the host machine afterwards, as the recordings are exposed within the container and thus open to tampering or malicious activity).

This is *very* thin in terms of a convincing honeypot -- it's trivially easy to spot that you're in a Docker container, the recordings are not exfiltrated stealthily, and a lone server with supervisor isn't exactly screaming "just a normal server here!" Some low hanging fruit is taken away, such as a renamed `ffmpeg` and the watch-and-record script being renamed to `systemd-monitor` (but even that is curious on a system not running systemd), but `supervisord` as PID 1 is obviously goofy.

__As the mounted directory offers write access to the host from within the container, you should consider any machine this is exposed on to be poisoned.__ I use a throwaway VPS that gets nuked when the experiment is done and fetch files via a bastion host. __Once again, this is *not* a secure setup and you should assume any and all parts of the system this is deployed on to be compromised!__ There are so many practices that make this container and its host unsafe. Use caution!

`./launch.sh` is intended to run on the top level host; it will build the docker image, create the recordings directory, and launch and expose the VNC container on port 5900 via host networking (you might need to open your firewall). The `bobby` user is just a random name used in the container so things don't run as root.

The container automatically restarts every 10 minutes to avoid becoming a permanent botnet node.

## What's What

`Dockerfile` stage one build (`vnc-base`) is a vanilla, perfectly "normal" VNC-enabled X11-via-Xfve4 docker container (running as root), operated by `supervisord` and the services in `supervisord-base.conf`. Stage 2 (`honeypot`) loads up a dummy user (`bobby`), `ffmpeg` (renamed to `systemd-helper`) and brings in the `supervisord-recording.conf` to set up the recording watcher `vnc-recording-monitor` (renamed to `systemd-monitor`) which watches for established port 5900 connections, then records out to `/recordings` which should be mounted via Docker.

## Getting rid of lame videos

Many attackers just connect and disconnect without doing anything. To clean up these recordings run `./filter-no-motion-videos.sh` which checks for motion and removes empty vids.

## Why?

Big ups to [@Xtrato](https://x.com/Xtrato/status/1939222218107445715) for the inspiration.
