# CIP - PWM Receiver Project

Circuitos Integrados: Projeto

## Course Overview

This repository contains the final project for the Synopsys course developed in collaboration with Prof. Cândido Duarte. The course focuses on digital design, HDL, verification, and fostering good practices in Verilog coding, as well as learning new techniques in timing analysis, clock domain crossing, and robust hardware design. During the course, we used the Synopsys Verilog Compiler and Simulator (VCS) in class, while I also tested the designs at home using ModelSim.

### Students will learn:

- SystemVerilog / Verilog coding styles and best practices  
- Testbench creation, simulation, and debugging  
- **Clock Domain Crossing (CDC) techniques** and metastability handling  
- Design with constraints, clocks, resets, and timing closure  
- Using Synopsys toolchains - VCS 
- Integration of RTL modules, verification flows, and packaging

## PWM Receiver Features

The PWM Packet Receiver design implements a robust architecture capable of handling asynchronous and noisy environments. Key design features include:

* Resistance to random delays

* Supports various operating frequencies (as long as the delays introduced to simulate FF transitions are properly adjusted)

* Asynchronous differential inputs

* Asynchronous reset generation

* Packet transmission with jitter tolerance

* Error injection mechanisms for validation, including:

  * Invalid symbol duration

  * Missing SOP/EOP markers

  * Asynchronous reset during packet

  * Invalid PWM ratio

  * Missing SOP and EOP conditions

## Testbench

**Note:** The full verification testbench used during development is not included in this repository due to copyright restrictions.
