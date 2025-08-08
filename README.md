# MiniCUDA
A GPU designed using HDL 

A work in progress to make a more complete GPU

**GPU_v1:**  The design that supports Branch divergence.

**GPU_v2:**  The design that supports Branch divergence + Branch synchronization.

## A description of the **GPU_v1** and **GPU_v2**

Each thread in a warp can follow its execution path while preserving warp-level execution semantics thanks to the active-thread masking system and warp scheduler implemented by this GPU core.
Barrier synchronization (__syncthreads) is incorporated into the design to guarantee that threads can safely reconverge before continuing to execute in parallel.

## Important Features

## **1. Support for Branch Divergence**

Applies active-thread masks and per-thread program counters (PCs).
Following a conditional branch, threads within the same warp may execute distinct code paths.
To resume lockstep execution, warp execution serializes for divergent paths but reconverges when feasible.

## **2. Threads are grouped into warps by warp-based scheduling, which uses SIMT rules to execute them collectively.**

A warp scheduler uses active threads and readiness to determine which warp runs in each cycle.

## **3. Barrier Synchronization Support for __syncthreads at the hardware level.**

Prevents race conditions in shared resources by making sure every thread in a block reaches the barrier before any others do.

## **4. Architecture with Modular Cores**

The separate, reusable modules that make up the GPU core are:

Fetcher: Gets instructions out of the program's memory.

Decoder: Handles barrier instructions, decodes instructions, and detects changes in the control flow.

The scheduler manages divergence-aware execution and chooses active warps.

Registers: Local storage per-thread register file.

Arithmetic and logic commands are carried out by the ALU.

Data memory is interfaced with by LSUs (Load/Store Units).

PC Unit: Oversees branch target resolution and keeps track of per-thread program counters.

## **5. Configurable and parameterized**

Modifiable parameters for:

The quantity of cores

Number of threads per block

Addresses of program/data memory and data widths

The quantity of memory channels

Simple to scale down for small simulation runs or up for larger experiments.

## How to execute

### Clone the Repository

    git clone https://github.com/<your-username>/<repo-name>.git
    cd <repo-name>



