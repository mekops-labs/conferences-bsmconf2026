---
title: "Where the Chain of Trust Goes Dark — Slides"
marp: true
theme: mekops
paginate: true
---


<!-- _class: lead -->
<!-- _paginate: false -->

<div style="text-align:center">

# Where the Chain of Trust Goes Dark


### Extending verified boot to signed WebAssembly workloads on microcontrollers

</div>
<br/><br/><br/><br/><br/><br/>
<div style="text-align:right">

**Kamil Wcisło** — Boot Security Mastery 2026, Gdańsk

</div>

---

## Verified boot is solved on paper

- A hardware root of trust measures and authorizes each stage — bootrom →
  bootloader → **application image**.
- Then the chain **terminates at the application**.
- Everything the application loads **afterward** runs unverified.

## The devices that matter, load code after boot

OTA firmware modules, plugins, updatable logic. For a fleet of internet-facing
microcontrollers, *that* is the attack surface — and it sits **outside** the
boot-security envelope.

---

## Thesis

> On devices that run code they download, the **chain of trust is only as long
> as the runtime makes it.**

## Question

> How to secure small targets in a portable manner?

---

## WebAssembly 101

Not a language - a **compile target**: C, Rust, Zig and others compile **to**
it, and a **small virtual machine executes it**. Three properties do the
security work and none of them depend on an OS.

1. **Memory is one flat array the module owns** - addressed to module's own
   linear memory, every access is bounds-checked.<br/>*A pointer into the host, the
   runtime's own structures, or a neighbour is not forbidden, it is **not
   expressible***.
2. **The call stack is not in that memory** - return addresses live in the VM,
   out of reach. Overflow a buffer and you corrupt only the module's own data.
3. **No ambient authority** - a module can call only the functions imported
   into it. There is no syscall table to reach for.

---

## Against the thing you probably already know

|             | Container | Wasm module |
|-------------|-----------|-------------|
| Boundary    | the **kernel** | the **instruction set** |
| Shares      | kernel, environment | **nothing** |
| Host access | syscalls (minus filtered) | imported funcs |
| Memory      | MMU-controlled address space | bounds-checked array |
| To escape   | kernel bug or a loose cap | a bug in the runtime |
| Requires    | MMU and Linux | **neither** |

---

## Against the thing you probably already know, cont.

The deepest difference is **the default**:
- a container starts with **everything and you take things away**
- a module starts with **nothing and you hand things in**

---

## What that buys, and what it does not

Wasm itself only isolates a module **inside** a process. That is a real
boundary, and it is silent about two things.

| Wasm answers | Wasm says nothing about |
|--------------|-------------------------|
| Can this code tries to reach memory it **does not own**? | Where did this code **come from**? |
| Can it call something it was **not given**?     | What is it **allowed to touch** on this device? |

Isolation is not provenance, and it is not authority - perfectly sandboxed
module of unknown origin, granted everything, is still a bad day.

---

## Let's try to answer all

<table style="border-collapse:collapse; margin:0"><tr>
<td style="border:none; padding:0 1.5em 0 0">
<div style="text-align:center">

**WANTED**<br/>_**W**eb**A**ssembly **N**anocontainer **T**echnology for
**E**mbedded **D**evices_

</div>
</td>
<td style="border:none; padding:0">

![width:180px](./wanted.svg)

</td>
</tr></table>
<style scoped>
table td p { margin: 0; }
</style>

OSS runtime for ARM/RISC-V/Xtensa/x86 (and possibly
others) - treats the post-boot gap as a first-class boot-security problem.

- **engine** — one process; a Wasm interpreter (**WAMR**) and a filesystem
  router
- **wapp** — an **OCI image** with Wasm module + ro filesystem with static data
- **supervisor** — a privileged wapp that reconciles what the engine runs
  against **signed desired state**
- **control plane** — signs that state, supervisor verifies it

---

## Let's try to answer all, cont.

**What it adds on top of Wasm:** 
- **provenance** — images signed and checked at every load - _do we know the source_
- **authority** — capabilities granted from outside the image - _what we allow_
- **identity** — desired state bound to one device and one generation - _what we actually run and where_

--- 

## What a wapp actually is

A **wapp** is an OCI image whose layers carry a **WebAssembly module** and its
read-only filesystem — pulled from an docker-compatible registry, exactly like
an usual container image. The packaging is the same.

- **One OS process, thread per workload**: a running wapp is an interpreter
  instance and a thread inside the engine.
- **The image cannot ask for anything**: a wapp image has no way to express a
  request — its authority arrives in the launch config the supervisor installs.
- **Same bytes, every target**: the identical wapp runs on Linux and on a
  Cortex-M33 with no recompile.

The image is **pure content**. Everything an attacker would want to *grant* it,
lives in the desired state, transmitted on a secure channel, and signed.

---

## Why Wasm, specifically

The isolation is a property of the **instruction set** — which matters when your
MCU has no MMU to build a ring with.

- **Bounds-checked linear memory**: a wapp addresses only its own memory, every
  access is checked by the interpreter. Enforced by WAMR.
- **No W^X window at all**: WAMR's classic interpreter mode means no code
  generation — nothing to make writable-then-executable. Pays with perf.
- **No ambient syscalls:** the only host interface is the WASI bridge, and every
  call routes through the VFS.

**The honest limit:** the interpreter is trusted. A WAMR vulnerability is an
engine vulnerability.

---

## One continuous chain

```sh
verified boot              # silicon: bootrom + OTP
        ▼
WANTED Engine  ◀──── hardware-rooted device identity
        ▼
signed desired state       # control plane and supervisor
        ▼
signed wapp                # checked at every load
        ▼
caps-confined execution    # Wasm linear memory + WASI
```

Each hop is a distinct trust layer with its **own key** or its **own gate**.

---

## Link 1 — Hardware root of trust

- **RP2350:** device identity sealed in on-die **OTP** behind bootrom-verified
  **signed boot** (secp256k1 + a hardware SHA-256 accelerator). **TrustZone-M**
  available to additionally isolate the control plane from workloads - not used
  for now.

**Two distinct, chained key layers:**

| Layer | Key | Authorizes |
|-------|-----|------------|
| Boot (silicon)         | **secp256k1** | *firmware image* |
| Control plane (WANTED) | **Ed25519**   | *runtime workloads* |

---

## Link 2 — Signed control plane

The on-device supervisor — **Sheriff** — accepts only **Ed25519-signed desired
state**.

- Monotonic **`generation`** counter — an old or equal generation is rejected.
- **`device_id`** bound into the signed payload — a valid signature for device A
  is rejected on device B.
- The signing input is the deterministic message payload **excluding
  the signature** — spliced out before verify.

Least-trust posture: **only** Sheriff holds credentials to the control plane.

Public control plane key is provisioned to the device's side during **enrollment
process**.

---

## Link 3 — Signed images, checked at every load

Workloads ship as **content-addressed OCI layers**, SHA-256-verified in flight. 

That is the easy half. The hard half is **at rest**: the bytes sat in flash
between the download and this boot.

So the engine re-checks on every load. The signed message binds **identity to
content**:

*u8 len(name) | name | u8 len(version) | version | u8 count | digest₀ ..
digestₙ₋₁*


--- 

## Link 3 — Signed images, checked at every load, cont.

- The **length prefixes** are important: without them `foo`/`1.0` and
  `foo1`/`.0` assemble the same bytes.
- Binding name and version closes **interposition** — validly signed bytes
  installed under *another* image's reference verify against a real key, and
  would be accepted by a payload that named only the bytes.
- The verifying keyring is **compiled into the firmware**, so whatever covers
  the firmware covers the keys:
  -  multiple slots, so a key can be retired without stranding images signed by
  the old one,
  -  changing the keyring itself takes a firmware update.

---

## Link 4 — Capability confinement

Every workload runs in a **WASI sandbox with no ambient authority**. Hardware,
network, and filesystem exist only as **explicitly mounted, policy-authorized
capabilities** — a Plan 9-inspired VFS where *if a node isn't mounted, it's
invisible.* Example grant in desired state:

```json
{ "mounts":  [{ "name": "platform",
  "path": "/data", "options": "ro" }],   // /data (ro)
  "drivers": [{ "name": "gpio" }],       // /dev/gpio
  "sockets": [{ "name": "uplink",        // /net/uplink
    "address": "tcps://192.168.1.1:8443" }] 
} 
```

That grant **is** the capability set — no more, no less.

---

## Power-on to a wapp running (RP2350 example)

1. Bootrom loads the sealed firmware, verifies with *secp256k1*
2. *WantedStart()* parses config, mounts the namespaces
3. Supervisor image gets loaded.
4. Supervisor fetches desired state from the control plane: *Ed25519* signature,
   *generation*, *device_id*
5. Supervisor installs the image and its signature into the registry.
   *SHA-256*-summed over the install stream, recorded beside the image
6. Engine loads the image, layers re-hashed, image **signature verified
   against the firmware keyring**
7. WAMR instantiates the module, allocates mem, imports WASI funcs
8. Launch config applied, entrypoint runs, the config *is the capability set* —
   mounts, drivers, sockets

---

## The OTA update is where the chain often breaks

Verified boot proves the image **you already have**. The interesting question
is: *what authorizes the image you are about to become?*

On the RP2350 the bootrom answers it with **A/B slots and Try-Before-You-Buy¹**:

- The new image is staged into the slot that is **not** running.
- It is marked **provisional**. The loader boots it *on trial*.
- If nothing confirms it, the next reset **reverts to the previous slot.** A bad
  update costs a reboot.

<br/><br/>
<span style="font-size:0.6em">1. *RP2350 Datasheet, §5.1.17 "Try Before You Buy"
(p.355)*</span>

---

## The demo: one cable, no network

**Live, on an Adafruit Feather RP2350** — no network stack on the board:

- it **enrols** — a one-use join token redeemed for a per-device secret
- **Ed25519-verified desired state** arrives over that cable
- a **signed wapp** is published, signature-checked by the control plane,
  carried over the same cable, and run

---

## Takeaways

1. A verified boot story is **incomplete** for any device that loads post-boot
   workloads, this is **runtime trust gap**.
2. Carrying hardware-rooted trust into a content-addressed, signed software
   supply chain on constrained MCUs **is possible**.
3. **Capability-based and memory confinements** (WASI / Plan 9-like VFS) on
   bounds-checked Wasm memory is the runtime complement to verified boot — least
   privilege, and a hard memory wall.
4. **Verify at load, not at download** - an in-flight digest proves what
   arrived, only an at-rest check proves what is about to run.

---

## The chain is only as long as your runtime makes it

> *Shameless plug*

- **WANTED** — OSS, Apache-2.0 -
  [mekops.com/projects/wanted](https://mekops.com/projects/wanted/)
- slides -
  [github.com/mekops-labs/conferences-bsmconf2026](https://github.com/mekops-labs/conferences-bsmconf2026)


<div style="text-align:center;">


<div style="display:inline-block; background:#000; padding:0.1em 0.1em; border-radius:32px;">

![width:200px](./mekops.svg)

</div>

<div style="font-size: 0.7em;">

© 2026 Kamil Wcisło — licensed under [CC BY-NC
4.0](https://creativecommons.org/licenses/by-nc/4.0/)

</div>

</div>
