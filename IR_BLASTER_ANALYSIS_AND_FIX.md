# Deep Technical Analysis & Fix: Infrared (IR) Blaster on Xiaomi Breeze
### Redmi 13 5G / POCO M6 Plus 5G · Snapdragon 4 Gen 2 (SM4450) · Project Infinity-X (Android 17)

---

## 1. Executive Summary & Verification
The infrared (IR) transmitter stack on Xiaomi Breeze (`breeze` / `breeze_in`) has been deeply analyzed, re-engineered, and confirmed **100% working**.

### Key Milestones:
- Hardware bus identified: Qualcomm QUPv3 Serial Engine 6 in SPI master mode (`qupv3_se6_spi` slave `spi_ir@1`).
- Kernel module reversed: `ir-spi.ko` character device exposing `/dev/ir_spi` with custom buffer ioctl `0x40046911`.
- SELinux denials resolved: symlink resolution allowed for `hal_ir_default`.
- HAL patched & verified: upstream `ConsumerIr.cpp` automatically discovers `/dev/ir_spi`, pre-sizes buffer with `IR_SPI_SET_BUF_SIZE`, and transmits infrared pulse patterns directly.

---

## 2. Hardware & Device Tree Layer (`dtbo.img`)

In Xiaomi devices based on the SM4450 platform, the IR transmitter LED is not driven by standard PWM or GPIO bit-banging. Instead, it is connected to a Serial Peripheral Interface (SPI) master on Qualcomm's QUPv3 engine.

```dts
fragment@33 {
    target = <&qupv3_se6_spi>;

    __overlay__ {
        status = "ok";

        spi_ir@1 {
            compatible = "ir-spi-led";
            reg = <0x01>;
            spi-max-frequency = <0x02faf080>; /* 50 MHz */
            spi-cpol;
            status = "ok";
        };
    };
};
```

* **Bus:** QUPv3 Serial Engine 6 in SPI master mode (`qupv3_se6_spi`).
* **Slave Select / CS:** Chip-select 1 (`reg = <0x01>`).
* **Clock Configuration:** `spi-cpol` (idle clock high), maximum clock 50 MHz.
* **Compatible Driver:** `"ir-spi-led"` (matches driver alias in `ir-spi.ko`).

---

## 3. Kernel Driver Reverse Engineering (`ir-spi.ko`)

Located at `device/xiaomi/breeze-kernel/vendor_ramdisk/ir-spi.ko`, loaded during early boot via `vendor_ramdisk/modules.load`.

### 3.1 Initialization & Registration
* The driver does not depend on `rc-core` (absent in generic GKI kernels).
* Registers a raw character device: `/dev/ir_spi` via `misc_register()`.
* In `ir_spi_probe()`, it pre-allocates an initial 150,000-byte kernel transmission buffer (`0x249f0` bytes) via `kmalloc`.

### 3.2 IOCTL Function (`ir_spi_chardev_ioctl`)
Decompilation of `ir_spi_chardev_ioctl`:
```assembly
00000000000004c0 <ir_spi_chardev_ioctl>:
     4f0: mov  w8, #0x6911
     4f4: movk w8, #0x4004, lsl #16   ; w8 = 0x40046911 (_IOW('i', 0x11, __u32))
     4f8: cmp  w20, w8                ; compares ioctl command code
     4fc: b.ne 0x5f8                  ; if != 0x40046911, returns -EINVAL (-22)!
```

#### What `0x40046911` (`IR_SPI_SET_BUF_SIZE`) Actually Does:
```assembly
     644: ldr  w8, [x21, #0x38]       ; current buffer_size
     648: cmp  w8, w20                ; compare with requested size (*arg)
     668: ldr  x0, [x21, #0x10]       ; buffer pointer
     674: bl   krealloc               ; reallocate buffer to size w20
     6a0: str  w20, [x21, #0x38]      ; idata->buffer_size = *arg
```
In Xiaomi's driver, ioctl `0x40046911` is **`IR_SPI_SET_BUF_SIZE`** (pre-allocating and setting the expected write buffer size), **not** setting carrier frequency!

### 3.3 Write Function (`ir_spi_chardev_write`)
```assembly
00000000000002bc <ir_spi_chardev_write>:
     304: ldr  w8, [x23, #0x38]       ; load idata->buffer_size
     308: cbz  w8, 0x350              ; IF buffer_size == 0 -> PROCEED (dynamic mode)!
     30c: cmp  x8, x19                ; IF buffer_size != 0 -> DOES COUNT MATCH?
     310: b.eq 0x350                  ; if match -> PROCEED
     328: mov  x0, #-0x16             ; IF MISMATCH -> RETURN -EINVAL (-22)!
     ...
     3b4: bl   _copy_from_user        ; copy bytes from userspace
     3d4: str  x8, [x23, #0x28]       ; xfer.tx_buf = user buffer
     43c: bl   spi_sync               ; sync SPI transfer over bus!
     46c: bl   kfree                  ; free transfer buffer
     470: str  wzr, [x23, #0x38]      ; resets idata->buffer_size back to 0!
```

---

## 4. Root Causes of Failure on Generic LineageOS / AOSP

1. **SELinux Symlink Denial (`lnk_file`):**
   `/dev/lirc0 -> /dev/ir_spi` is a symbolic link (`lnk_file`). Upstream SELinux policy only granted `chr_file` permissions to `hal_ir_default`. Opening `/dev/lirc0` failed with `EACCES` (*Permission denied*).
2. **IOCTL Incompatibility:**
   Upstream HAL called `ioctl(fd, LIRC_SET_SEND_CARRIER, &freq)` (`0x40046913`). The kernel driver rejected anything other than `0x40046911` with `-EINVAL` (`-22`), causing the HAL to abort with `EX_UNSUPPORTED_OPERATION`.
3. **Buffer Sizing Requirement:**
   If `idata->buffer_size != 0` and did not match the user write byte count, the driver aborted write operations.

---

## 5. Applied Fixes

### 5.1 HAL Implementation (`hardware/lineage/interfaces/ir/ConsumerIr.cpp`)
- Probes `/dev/ir_spi` directly before falling back to `/dev/lirc0`.
- Pre-sizes the transfer buffer with `IR_SPI_SET_BUF_SIZE` (`0x40046911`) prior to write.
- Treats carrier ioctls as non-fatal warnings on devices where hardware SPI carrier modulation is preconfigured.

### 5.2 SELinux Policy (`device/lineage/sepolicy/common/vendor/hal_ir_default.te`)
```te
allow hal_ir_default { device lirc_device }:lnk_file r_file_perms;
```

### 5.3 Init Script Configuration (`device/xiaomi/breeze/init/etc/init.target.rc`)
```rc
    # IR
    chown system system /dev/ir_spi
    chmod 0660 /dev/ir_spi
    restorecon /dev/ir_spi
    symlink /dev/ir_spi /dev/lirc0
    chown system system /dev/lirc0
    restorecon /dev/lirc0
```
