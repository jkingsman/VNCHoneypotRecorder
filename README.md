# VNC Honeypot in Docker

### __Warning! Don't run this on systems you care about! This is a very poorly isolated honeypot, and it doesn't take a ton of work to break out. This is good (?) for throwaway servers you reimage afterwards. Exfiltrate recordings with care!__

This Docker image contains the bare bones of a Xfce4 and a VNC server. `supervisord` manages the X environment, VNC server, and a script that listens for established port 5900 connections then starts an `ffmpeg` recording and dumps a video of the session to a temporar

You should read all the warnings in here, but to get started fast, have Docker installed and run:

```bash
git clone https://github.com/jkingsman/VNCHoneypotRecorder.git
cd VNCHonepotRecorder
./launch.sh
```

This will launch a VNC honepot running on port 5900.

`./launch.sh` is intended to run on the top level host; it will build the docker image, create the recordings directory, and launch and expose the VNC container via host networking (you might need to open your firewall). When the container is stopped, recordings are automatically copied from the container to the host's `recordings/` directory. The `bobby` user is just a random name used in the container so things don't run as root.

### More Warnings

This is *very* thin in terms of a convincing honeypot -- it's trivially easy to spot that you're in a Docker container and a lone server with supervisor isn't exactly screaming "just a normal server here!" Some low hanging fruit is taken away, such as a renamed `ffmpeg` and the watch-and-record script being renamed to `systemd-monitor` (but even that is curious on a system not running systemd), but `supervisord` as PID 1 is obviously goofy.

__We blindly copy files out of an attacker-controlled environment -- you should consider any machine this is exposed on to be poisoned!__ I use a throwaway VPS that gets nuked when the experiment is done and fetch files via a bastion host. __Once again, this is *not* a secure setup and you should assume any and all parts of the system this is deployed on to be compromised!__ There are so many practices that make this container and its host unsafe. Use caution!

## What's What

`Dockerfile` stage one build (`vnc-base`) is a vanilla, perfectly "normal" VNC-enabled X11-via-Xfce4 docker container, operated by `supervisord` and the services in `supervisord-base.conf`. It creates and runs as the `bobby` user for better security. Stage 2 (`honeypot`) adds `ffmpeg` (renamed to `systemd-helper`) and brings in the `supervisord-recording.conf` to set up the recording watcher `vnc-recording-monitor` (renamed to `systemd-monitor`) which watches for established port 5900 connections, then records to `/tmp/recordings` inside the container. Recordings are copied to the host before container cleanup in the `./launch.sh` script.

## Getting rid of lame videos

Many attackers just connect and disconnect without doing anything. To clean up these recordings run `./filter-no-motion-videos.sh` which checks for motion and removes empty vids.

## Why?

Big ups to [@Xtrato](https://x.com/Xtrato/status/1939222218107445715) for the inspiration.
