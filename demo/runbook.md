# Demo runbook

Operator procedure for the live demo: an Adafruit Feather RP2350 reaching a
control plane on the laptop over USB, with no network on the board.

Paths are relative to the workspace that holds the code repositories. 
- The engine is [wanted-engine](https://gitlab.com/mekops/wanted/wanted-engine). 
- The control plane is [deputy](https://gitlab.com/mekops/wanted/deputy). 
- The image signer is [wsign](https://gitlab.com/mekops/wanted/wsign).

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
for t in /dev/ttyACM*; do
    n=$(basename "$t"); d=$(readlink -f "/sys/class/tty/$n/device")
    while [ "$d" != "/" ]; do
        [ -f "$d/idVendor" ] && { printf '%-14s %s\n' "$t" "$(cat "$d/idVendor")"; break; }
        d=$(dirname "$d")
    done
done
```

- Vendor id `2e8a` is the Debug Probe. This is the console.
- Vendor id `0525` is the board's own CDC port. This is the control-plane link.

## A. One-time setup

Do this section on a new laptop only.

### A1. Registry

```sh
podman run -d --name demo-registry -p 5000:5000 docker.io/library/registry:2
```

### A2. Keys

The image-signing public half is compiled into the firmware. The control-plane
signing seed is given to the server at start.

```sh
wsign/bin/wsign keygen --out wanted-engine/keys/image-signing-demo.pem
openssl rand -hex 32 > wanted-engine/keys/deputy-signing-seed.hex
```

`keygen` prints the public half. Record it. A new image-signing key needs a new
firmware build. A new signing seed needs a new enrolment.

### A3. Images

Build two images from the same bytes. Sign one of them. The unsigned image is
the refusal demo.

```sh
mkdir -p looper-img && cp wanted-engine/wapps/looper/looper.wasm looper-img/app.wasm
printf 'FROM scratch\nCOPY app.wasm /app.wasm\n' > looper-img/Containerfile
cd looper-img
podman build -t localhost:5000/looper:1.0.0 . && podman push --tls-verify=false localhost:5000/looper:1.0.0
podman build -t localhost:5000/rogue:1.0.0  . && podman push --tls-verify=false localhost:5000/rogue:1.0.0
```

### A4. Signature

Sign `looper` only.

```sh
wsign/bin/wsign publish --insecure \
    --key wanted-engine/keys/image-signing-demo.pem --key-id 1 \
    localhost:5000/looper:1.0.0
```

### A5. Firmware

```sh
cd wanted-engine
make defconfig rp2350_feather_sheriff && NUTTX_CLEAN=1 make build
make rp2350-flash-swd
```

`NUTTX_CLEAN=1` is necessary after a change to a board defconfig, a build
profile, or the supervisor. Without it the build uses the previous values and
reports success. After the build, examine the value in
`third_party/nuttx/.config` to confirm the change is present.

## B. Start the control plane

The control plane stops when its serial device disappears. Each board reset does
this. Start it in a loop that waits for the port.

```sh
export DEPUTY_IMAGE_SIGNING_KEYS="1:<image-signing public half>"
while true; do
    board=$(find_port 0525) && \
      deputy/deputy server --serial "$board" --listen 127.0.0.1:8080 \
        --signing-seed="$(cat wanted-engine/keys/deputy-signing-seed.hex)" \
        --db "$WORK/deputy.db" --layer-cache "$WORK/layers" \
        --registry-address localhost:5000 --oci-insecure --require-signed-images
    sleep 0.5
done
```

Before you continue, check two conditions.

- Exactly one server process is active.
- The log contains `image signature verification enabled … required=true`.

If a second server process starts, it stops on the port and the first process
continues to serve. A push then goes to the process without signature
verification.

## C. Enrol the board

Do this once for each new board. Do it again after the flash filesystem is
formatted.

1. Issue the blob. It expires after approximately 15 minutes.

   ```sh
   deputy/deputy device enrol
   ```

   The command prints JSON, then the base64 blob on its own line.

2. Reset the board and open the console.

   ```sh
   cd wanted-engine && make rp2350-reset
   picocom -b 115200 /dev/ttyACM<probe>
   ```

3. The board prints `no device identity. paste a provisioning blob ...`. Paste
   the base64 line within 30 seconds. Press Enter.

4. The board answers `stored 276 B at sheriff/provision`.

5. Confirm the device is present and record the device id.

   ```sh
   deputy/deputy device list
   ```

   The `LINK` column reads `serial`.

## D. The demo

1. Show the device reporting:

    ```
    deputy/deputy device list
    ```

   `LINK` reads `serial`. `LAST SEEN` advances.

2. Push the signed wapp:

   ```sh
   deputy/deputy device wapp create --version=1.0.0 \
       --image=localhost:5000/looper:1.0.0 <device-id> looper
   ```

4. What happens:

   - The control plane verified the signature before it sent the state.
   - The supervisor carries the signature and does not check it.
   - The engine hashes the layers again and checks the signature against the
     keyring compiled into the firmware, at every load.

5. Wapp running:

   ```sh
   deputy/deputy device show <device-id>
   ```

   The output reports `looper ... RUNNING`. Enforcement is active in this build,
   so a load that runs is a load that verified. A failed check refuses the load.

6. Show the first refusal. The control plane rejects the unsigned image.

   ```sh
   deputy/deputy device wapp create --version=1.0.0 \
       --image=localhost:5000/rogue:1.0.0 <device-id> rogue
   ```

   The command reports `400 Bad Request: image carries no signature`. The image
   does not reach the board.

7. Show the second refusal. Restart the control plane without
   `--require-signed-images`. Push `rogue` again. The image reaches the board
   and the engine refuses it at load.

   ```sh
   deputy/deputy device show <device-id>
   ```

   The output reports the two together, from one identical layer digest.

   ```
   looper  1.0.0  RUNNING
   rogue          ABSENT
   ```

   The board also holds its acknowledged generation at the previous value.

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
  the board powered off. Reset the board.
- **The console gives no output:** set the line discipline before you read the
  port. Use a terminal program. As an alternative, run `stty -F <port> 115200
  raw -echo` first.
- **The device does not appear:** examine the number of server processes.
  Exactly one is correct. Then reset the board.
- **A push has no effect:** layer acquisition runs only on a tick that applies a
  new generation. Remove the wapp and create it again.
