https://www.realdigital.org/hardware/boolean

# UART-Based MNIST Image Transfer & Verification (FPGA ↔ Python GUI)

End-to-end system to send **MNIST pixels** from a Python GUI to an FPGA over **UART**, echo them back, and **verify** byte-for-byte correctness in real time. One image ⇒ **784 packets** (28×28), each **24 bits**.

---

## Overview

- **Python GUI (`main.py`)**
  - Select & preview MNIST test images.
  - Stream packets over UART (default **625000 baud**).
  - Show live logs of **Sent** and **Incoming** data.
  - Auto-compare sent vs. received; reports **first mismatch** and summary.

- **Packet Builder (`packet_builder.py`)**
  - Builds a fixed **24-bit** packet per pixel:
    ```
    [3-bit Header] + [10-bit Location] + [8-bit Data] + [3-bit XOR Footer]
    ```
  - Header = `101`.
  - Footer integrity bits:
    - `F2 = XOR(DATA[7:0])`
    - `F1 = XOR(LOC[9:0])`
    - `F0 = XOR(DATA[7:4] + LOC[9:5])`
  - Output as **3 bytes (big-endian)** and hex string.

- **FPGA (`top_module.v`)**
  - UART RX/TX + packet validation (header/footer).
  - BRAM write/read for pixel storage.
  - Echoes validated packets back to host.

---

## Packet Layout (24 bits)

```
|  H2 H1 H0  |  LOC[9:0]  |  DATA[7:0]  |  F2  F1  F0  |
|   3 bits   |   10 bits  |    8 bits   |    3 bits    |
```
- **Header**: `1 0 1`
- **Footer**: XOR integrity (see above)
- **Serialization**: 3 bytes, **big-endian** (byte0=bits[23:16], byte1=bits[15:8], byte2=bits[7:0])

---

## Requirements

### Python
- Python 3.9+
- `pillow`, `torchvision`, `pyserial`
- MNIST dataset available to `torchvision.datasets.MNIST(train=False, download=False)` (or set `download=True`)

Install:
```bash
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

pip install pillow torchvision pyserial
```

### FPGA
- UART RX/TX at **625000 bps**
- BRAM for at least 784 entries (addressing 0..783)
- Packet validator (header `101`, XOR footer), echo path

---

## Setup & Usage

1. **Wire UART** between FPGA and host .
2. **Configure port** in `main.py`:
   - Windows: `port_ = "COM12"`
   - Linux/macOS: e.g. `"/dev/ttyUSB0"` or `"/dev/ttyACM0"`
3. **Load bitstream** to FPGA (ensure UART baud & pins match).
4. **Run GUI**:
   ```bash
   python main.py
   ```
5. In the GUI:
   - Enter MNIST **index** (0–9999) → **Show**
   - Click **Send** → streams **784 packets** and listens for echo
   - Check **Sent** and **Incoming** panels + summary popup

---

## Verification Logic (Host)

- Tracks **sent_packets** and **recv_packets** (byte-accurate).
- Completion condition:
  ```
  sent == 784  AND  recv == 784  AND  mismatches == 0  → PASS
  ```
- On FAIL:
  - Shows total mismatches
  - Shows **first mismatch index** with `sent` vs `recv` hex

---

## Notes & Tips

- **Baud exactness** matters at 625000 bps; clocking/timing must be clean on FPGA.
- Host reads in **chunks of 3 bytes** to maintain packet alignment.
- If MNIST isn’t present, set `download=True` in `main.py` or prepare `mnist_data/`.
- If you see timeouts, verify cable, port name, and FPGA echo path.

![boolean_board](https://github.com/user-attachments/assets/6c4570eb-066c-4f6d-98d7-8bd02f26b06c)
<img width="796" height="427" alt="Ekran görüntüsü 2025-08-12 113131" src="https://github.com/user-attachments/assets/75830f32-1e47-4550-951e-c81c4f87e062" />



