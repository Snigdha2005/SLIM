# SLIM: A Scalable Large Integer Multiplier with Run-time Configurable Operand Length for FPGAs

## Overview

SLIM is a parameterized large integer multiplier architecture designed for FPGA implementation. The design supports run-time configurable operand lengths while maintaining reusable hardware resources through BRAM-based storage and scheduling.

The architecture is implemented in Verilog and is optimized for scalable multiplication of large operands using configurable base multipliers.

The main source file is:

```text
generic_multiplier_vivado.v
```

This file contains the following modules:

* `generic_base_multiplier`
* `generic_multiplier`

---

# Design Parameters

SLIM supports three design-time configurable parameters:

| Parameter | Description                     |
| --------- | ------------------------------- |
| `x`       | Width of the base multiplier    |
| `y`       | Streaming interface width       |
| `n`       | Maximum supported operand width |

These parameters map to the Verilog implementation as follows:

| Paper Parameter | Verilog Parameter        |
| --------------- | ------------------------ |
| `x`             | `base_mult`              |
| `y`             | `interface_bits`         |
| `n`             | `bram_depth * base_mult` |

---

# Operand Representation

Two input operands:

```text
A and B
```

each have width:

```text
w = 2^Size
```

where `Size` is provided at runtime.

The architecture supports multiplication of operands up to the maximum configured width.

---

# Main Modules

## 1. generic_base_multiplier

This module performs the actual base multiplication operation.

### Features

* Configurable multiplier width
* Operand multiplexing
* DSP inference support
* Registered input staging
* Shared multiplier datapath

### Parameters

```verilog
parameter base_mult
```

### Functionality

The module:

* Selects operands from BRAM outputs or streamed interface inputs
* Performs multiplication
* Outputs a `2 * base_mult` width result

---

## 2. generic_multiplier

This is the top-level SLIM architecture.

### Features

* Runtime configurable operand length
* BRAM-based operand storage
* Partial product accumulation
* Streaming input/output support
* Configurable interface width
* Reusable multiplier datapath
* Parameterized scheduling

### Parameters

```verilog
parameter base_mult
parameter interface_bits
parameter bram_depth
```

### Parameter Mapping

```text
base_mult     = x
interface_bits = y
bram_depth    = n / x
```

---

# Architecture Overview

The SLIM architecture consists of:

1. Input BRAM subsystem
2. Operand scheduling logic
3. Base multiplier datapath
4. Partial product accumulation BRAM
5. Reconstruction logic
6. Streaming output subsystem

---

# BRAM Requirements

SLIM requires three BRAM IP instances generated using the Vivado IP Catalog.

---

# BRAM Configuration

## 1. Input BRAM (`a`)

Stores input operands.

### Configuration

| Property  | Value            |
| --------- | ---------------- |
| BRAM Type | Single Port RAM  |
| Width     | `base_mult`      |
| Depth     | `bram_depth / 2` |

### Notes

* Two instances are used for operand A
* Two instances are used for operand B

---

## 2. Partial Product BRAM (`outp`)

Stores accumulated partial products.

### Configuration

| Property       | Value                                |
| -------------- | ------------------------------------ |
| BRAM Type      | True Dual Port RAM                   |
| Port Width     | `2*base_mult + log2(bram_depth) + 1` |
| Depth          | `2*bram_depth - 1`                   |
| Operating Mode | Read First                           |

### Important Settings

#### Port A

* Disable:

  ```text
  Primitive Output Register
  ```

#### Port B

* Disable:

  ```text
  Primitive Output Register
  ```

### Notes

Both ports must use identical configurations.

---

## 3. Intermediate BRAM (`a_out1`)

Used only when:

```text
base_mult != interface_bits
```

This BRAM stores intermediate output data before streaming.

### Configuration

| Property  | Value              |
| --------- | ------------------ |
| BRAM Type | Single Port RAM    |
| Width     | `base_mult`        |
| Depth     | `2*bram_depth - 1` |

### Important Settings

Disable:

```text
Primitive Output Register
```

---

# Vivado IP Generation Steps

## Step 1 — Create BRAM IP

Open:

```text
IP Catalog → Block Memory Generator
```

---

## Step 2 — Configure BRAM

Create the following IPs:

### Input BRAM

```text
Name: a
Type: Single Port RAM
```

### Partial Product BRAM

```text
Name: outp
Type: True Dual Port RAM
```

### Intermediate BRAM

```text
Name: a_out1
Type: Single Port RAM
```

---

# Runtime Operation

The architecture operates in the following stages:

---

## 1. Operand Loading

Operands are streamed into input BRAMs through the interface.

---

## 2. Operand Scheduling

The scheduler generates operand pair combinations dynamically.

---

## 3. Base Multiplication

The selected operand blocks are multiplied using:

```text
generic_base_multiplier
```

---

## 4. Partial Product Accumulation

Partial products are accumulated into the `outp` BRAM using shift-index-based addressing.

---

## 5. Reconstruction

The accumulated values are read back and carry propagation is performed.

---

## 6. Output Streaming

Results are streamed through the output interface.

---

# Design Characteristics

## Advantages

* Runtime configurable operand width
* Parameterized architecture
* BRAM-efficient implementation
* Reusable multiplier datapath
* DSP inference support
* Supports very large integer multiplication
* Streaming-compatible interface

---

# Important Notes

## DSP Inference

The design uses:

```verilog
(* use_dsp = "yes" *)
```

attributes to infer DSP blocks for multiplication and addition.

---

## BRAM Output Registers

For correct timing behavior:

```text
Primitive Output Register
```

must be disabled for:

* `outp`
* `a_out1`

---

## Supported Configurations

Example configurations:

| base_mult | interface_bits | Maximum Operand Width |
| --------- | -------------- | --------------------- |
| 32        | 32             | 2048                  |
| 64        | 32             | 4096                  |
| 128       | 64             | 8192                  |
| 256       | 128            | 16384                 |

---

# File Structure

```text
generic_multiplier_vivado.v
│
├── generic_base_multiplier
└── generic_multiplier
```

---

# Toolchain

* Vivado
* Verilog HDL
* AMD/Xilinx FPGA devices

---

# FPGA Resource Usage

The architecture primarily uses:

* DSP slices
* BRAMs
* LUTs
* Flip-flops

Resource utilization depends on:

* `base_mult`
* `interface_bits`
* `bram_depth`

---

# Suggested Synthesis Settings

Recommended Vivado options:

```text
Performance_Explore
```

and

```text
phys_opt_design
```

for improved timing closure.

---

# Example Parameter Configuration

```verilog
generic_multiplier #(
    .base_mult(128),
    .interface_bits(128),
    .bram_depth(512)
)
```

This configuration supports:

```text
Maximum operand width = 128 × 512 = 65536 bits
```
