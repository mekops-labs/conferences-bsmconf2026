# Running this runbook on macOS

The runbook in this directory was written for Linux. Three things differ on
macOS; apply all of them together, on any Mac running this demo.

## 1. Port identification

`/dev/ttyACM*` and `/sys/class/tty` don't exist on macOS. Serial ports show up
as `/dev/cu.usbmodemNNNN`, and the USB vendor id has to come from `ioreg`
instead of sysfs. Use `macos-ports.sh` in this directory in place of the
runbook's "Identify the two serial ports" script:

```sh
./macos-ports.sh              # list every USB-serial port, with vendor:product id
source ./macos-ports.sh
find_port 0525                # prints the board's port, exit 1 if not attached
```

The vendor ids are the same as the runbook documents: `2e8a` is the Debug Probe
(console), `0525` is the board's own CDC (control-plane link). Use `find_port`
wherever the runbook's control-plane loop (section B) calls the `find_port`
shell function — it isn't a system builtin on any OS; this script is what
defines it here.

## 2. `wsign` needs bash ≥4.4; macOS ships 3.2

Apple has frozen `/bin/bash` at 3.2.57 (GPLv2) for over a decade. `wsign`'s
`#!/usr/bin/env bash` shebang picks up whatever `bash` resolves first on
`$PATH`. Install a current bash and make sure it's ahead of `/bin` on `PATH`:

```sh
brew install bash   # lands at /opt/homebrew/bin/bash
```

Homebrew's install prefix is already ahead of `/bin` in the default macOS
`$PATH` layout, so no further `PATH` edit is needed once it's installed.

## 3. Hardware access doesn't reach a container on this Mac

`wanted-engine`'s `rp2350-flash-swd`, `rp2350-reset`, and `rp2350-otp` targets
run OpenOCD in a container with `--privileged -v /dev/bus/usb:/dev/bus/usb`.
That bind mount is Linux-only; podman's macOS machine runs its own Linux VM with
no passthrough to the Mac's USB stack — `/dev/bus/usb` does not exist inside it.
These targets cannot reach the board through the container on a Mac.

Install OpenOCD and picotool natively via Homebrew instead, and run them against
the host directly rather than through `$(RP2350_OPENOCD)`:

```sh
brew install openocd picotool picocom
```

- `rp2350-flash-swd` becomes: `openocd -f interface/cmsis-dap.cfg -c 'transport
  select swd' -f target/rp2350.cfg -c 'adapter speed 5000' -c 'program
  third_party/nuttx/nuttx verify reset exit'`
- `rp2350-reset` becomes: the same `openocd` invocation with `-c 'init; reset
  run; exit'` in place of the `program` line.
- `rp2350-flash` (BOOTSEL path) becomes: `picotool load -x
  third_party/nuttx/nuttx.uf2`
- The console (`picocom -b 115200 <port>`) already works unchanged — `picocom`
  itself is fine on macOS, it just isn't preinstalled.

None of `openocd`, `picotool`, `picocom`, or a modern `bash` are installable
through `mise` on this laptop — checked the `aqua`, `github`/`ubi`, and `pkgx`
backends; none carry a macOS binary for these (pkgx also requires enabling an
experimental mise setting, not done here). Homebrew is the correct source for
these four, not a workaround.

## 4. Registry port

Port 5000 is macOS's AirPlay Receiver (Control Center). This laptop's registry
runs on host port **5001** instead (`podman run -d --name demo-registry -p
5001:5000 …`). Every place the runbook says `localhost:5000`, read
`localhost:5001` on this laptop instead — image tags, `podman push`/`pull`,
`wsign publish` targets, and Deputy's `--registry-address`. The container's own
internal port is still 5000; only the host-side mapping changed, which is what
image tags and `--registry-address` actually reach.
