# Demo runbook

Operator procedure for the live demo: an Adafruit Feather RP2350 reaching a
control plane on the laptop over USB, with no network on the board.

Paths are relative to the workspace that holds the code repositories.
- The engine is [wanted-engine](https://gitlab.com/mekops/wanted/wanted-engine).
- The control plane is [deputy](https://gitlab.com/mekops/wanted/deputy).
- The image signer is [wsign](https://gitlab.com/mekops/wanted/wsign).


This runbook assumes macOS. `macos-notes.md`, in this same directory, states
each place the underlying commands differ from Linux, and why.

The demo runs one wapp throughout — `wsh` (`wanted-engine/wapps/wsh/`), an
interactive VFS shell. It proves the signed-install/refusal chain exactly like
any other wapp would.

## Hardware

- Connect a Raspberry Pi Debug Probe to `UART0` on `GPIO0` and `GPIO1`. This
  carries the console.
- The Debug Probe also supplies SWD, which flashes the board without the
  `BOOTSEL` button.
- Connect the Feather to the laptop with one USB cable. This cable carries power
  and the control-plane link.

## Identify the two serial ports

Each board reset gives the ports new numbers. Identify them by USB vendor id
before each use.

```sh
./macos-ports.sh
```

- Vendor id `2e8a` is the Debug Probe. This is the console.
- Vendor id `0525` is the board's own CDC port. This is the control-plane link.

## A. One-time setup

Do this section on a new laptop only.

### A1. Registry

```sh
./a1_registry.sh
```

### A2. Keys

The image-signing public half is compiled into the firmware. The control-plane
signing seed is given to the server at start.

```sh
wsign/bin/wsign keygen --out wanted-engine/keys/image-signing-demo.pem
openssl rand -hex 32 > wanted-engine/keys/deputy-signing-seed.hex
```

`keygen` prints the public half. Record it for the firmware build in A5. Later
steps read the key file directly, so no other manual copy is necessary. A new
image-signing key needs a new firmware build. A new signing seed needs a new
enrolment.

### A3. Images

Build two images from the same bytes. Sign one of them. The unsigned image is
the refusal demo. `wapps/wsh/` produces a plain `.wasm` via its own Makefile
(pass `NAME=wsh` — the Makefile otherwise derives the name from the mounted
directory, which is wrong when it's built inside a container).

```sh
cd wanted-engine/wapps/wsh
podman run --rm -v "$PWD:/src" --userns=keep-id -w /src \
    registry.gitlab.com/mekops/wanted/wanted-engine/wapp-sdk:latest make NAME=wsh
cd ../../..

mkdir -p wsh-img && cp wanted-engine/wapps/wsh/wsh.wasm wsh-img/app.wasm
printf 'FROM scratch\nCOPY app.wasm /app.wasm\n' > wsh-img/Containerfile
cd wsh-img
podman build -t localhost:5001/wsh:0.5.0 . && podman push --tls-verify=false localhost:5001/wsh:0.5.0
podman build -t localhost:5001/rogue:1.0.0 . && podman push --tls-verify=false localhost:5001/rogue:1.0.0
cd ..
```

### A4. Signature

Sign `wsh` only.

```sh
./a4_sign.sh wsh:0.5.0
```

### A5. Firmware

```sh
cd wanted-engine
make defconfig rp2350_feather_sheriff_wsh_demo && NUTTX_CLEAN=1 make build
cd ..
./a5_flash.sh
```

## B. Start the control plane

The control plane stops when its serial device disappears. Each board reset does
this. `start-deputy.sh` runs it in a loop that waits for the port and restarts
it, with signature verification required.

```sh
./start-deputy.sh
```

Before you continue, check two conditions.

- Exactly one server process is active: `pgrep -fl "deputy server"`.
- The log contains `image signature verification enabled … required=true`.

If a second server process starts, it stops on the port and the first process
continues to serve. A push then goes to the process without signature
verification. Use `./stop-deputy.sh` before starting a second time, so the two
never race.

## C. Enrol the board

Do this once for each new board. Do it again after the flash filesystem is reset
— see `reprovision.sh` in Troubleshooting.

1. Issue the blob. It expires after approximately 15 minutes.

   ```sh
   ./c1_enrol.sh
   ```

   This saves the device id to `demo-work/device-id`, for `push.sh` and
   `show.sh` to read, and prints the exact steps for the next parts.

2. Reset the board and open the console.

   ```sh
   ./reset.sh
   ./console.sh
   ```

3. The board prints `no device identity. paste a provisioning blob ...`. Paste
   the base64 line `enrol.sh` printed, within 30 seconds. Press Enter.

4. The board answers `stored 276 B at sheriff/provision`.

5. Exit the console: press Ctrl-a, then press Ctrl-x.

6. Confirm the device is present.

   ```sh
   ./deputy.sh device list
   ```

   The `LINK` column reads `serial`.

## D. The demo

### D1. Push `wsh`, granting it the console, `/dev/wanted`, Sheriff's log, and the LED

```sh
./d1_push.sh wsh 0.5.0 wsh:0.5.0
```

`push.sh` recognizes the name `wsh` and applies its demo grant (`WSH_POLICY` in
the script) automatically — nothing to type or paste live. Pass a 4th argument
to override it (e.g. push a bare `wsh` with no grants). The grant itself:

```json
{
  "drivers": [
    {"name":"wanted"},
    {"name":"log","path":"/logs","options":"name=supervisor"},
    {"name":"gpio","options":"pins=led:/dev/gpio7:out"}],
  "console": {"out":{"name":"platform"},"in":{"name":"platform"}}
}
```

### D2. Wapp running, signed

```sh
./d2_show.sh
```

The output reports `wsh ... RUNNING`. Enforcement is active in this build, so a
load that runs is a load that verified: the control plane verified the signature
before it sent the state, the supervisor carries the signature and does not
check it, and the engine hashes the layers again and checks the signature
against the keyring compiled into the firmware, at every load.

**One operational quirk worth knowing before doing this live:** after a
`push.sh`, the device sometimes doesn't pick up the new generation until the
board is reset once more (`./reset.sh`) — seen repeatedly on the bench, not yet
root-caused. Build a reset into the push→show handoff rather than waiting on a
stuck `AckGeneration`.

### D3. Show the first refusal. The control plane rejects the unsigned image.

```sh
./d1_push.sh rogue 1.0.0 rogue:1.0.0
```

The command reports `400 Bad Request: image carries no signature`. The image
does not reach the board.

### D4. Show the second refusal. Restart the control plane without `--require-signed-images`.

```sh
./stop-deputy.sh
./start-deputy.sh --unenforced
./d1_push.sh rogue 1.0.0 rogue:1.0.0
./d2_show.sh
```

The image reaches the board and the engine refuses it at load. The output
reports the two together, from one identical layer digest.

```
wsh    0.5.0  RUNNING
rogue         ABSENT
```

The board also holds its acknowledged generation at the previous value.
`show.sh`'s `EngineLog` field names the reason directly: `refused: image
verification no_signature`.

Restart the control plane back to enforced (`./stop-deputy.sh` then
`./start-deputy.sh`) before continuing.

### D5. Drive it — the interactive walkthrough

```sh
./console.sh
```

**Use a real terminal program (`picocom`, `screen`), not a raw `cat`/`stty`
capture.**

Live transcript, `picocom -b 115200 <debug-probe-port>`:

```
> cat /proc/wanted
platform:	nuttx
version:	v0.20.3-dirty
...
drivers:	null log platform 9p config socket sha256 ed25519 inflate gpio ota wanted wifi

> write /dev/gpio/led/value 1
> cat /dev/gpio/led/value
1
> write /dev/gpio/led/value 0

> cat /logs/supervisor
[+330] sheriff v0.11.1-dirty starting
[+460] pool 131072 B (wanted 81920 B)
[+490] bounds wapps=16 layers=4 args=4 envs=4 drivers=8 desired=32768B report=4096B
[+660] sheriff v0.11.1-dirty: reconciling (device="dep-c76bbc373d0e7153", self="supervisor", engine="v0.20.3-dirty", ack_gen=17)
[+1450] fetch applied (accepted_gen=19)
[+1480] acquiring layers for 1 wapp(s)
[+1480] wsh: want sha256:2e9f9282bf4f: staged
[+12110] fetch no_change (accepted_gen=19)
```

## E. Secure boot, offline

This section needs no board and no network. It shows the firmware layer, below
everything in section D. Run it at any time.

```sh
cd wanted-engine
make rp2350-sign
```

The command does three things.

1. It signs the built firmware image with a secp256k1 key.
2. It confirms the signature is valid on that image.
3. It changes a copy of the image and confirms the check refuses it.

The output of the refused image reports the two fields to show the audience.

```
hash:                incorrect
signature:           incorrect
```

The run ends with two lines.

```
PASS: tampered try-before-you-buy image is correctly rejected
PASS: rp2350-sign-verify (signed-firmware pipeline validated offline, no OTP touched)
```

The same artifact carries the signature and the try-before-you-buy mark. The
mark is written before the seal, so the signature covers it.

## Troubleshooting

- **The board's CDC port is absent from the host:** the supervisor stopped and
  the board powered off. Reset the board: `./reset.sh`.
- **The console gives no output:** set the line discipline before you read the
  port. `console.sh` does this. As an alternative, run `stty -f <port> 115200
  raw -echo` first. If that still shows nothing, use `picocom`/`screen` instead
  of a raw `cat` capture — see D5.
- **The device does not appear:** examine the number of server processes.
  Exactly one is correct: `pgrep -fl "deputy server"`. Then reset the board.
- **A push has no effect:** layer acquisition runs only on a tick that applies a
  new generation. Remove the wapp and create it again.
- **The board needs a new enrolment, without a full reflash:** run
  `./reprovision.sh`, then repeat section C. This clears the identity file and
  any installed wapp state, in seconds, without touching firmware or keys. For a
  guaranteed clean state instead, at the cost of several minutes, run
  `./erase.sh` and repeat section A5.
