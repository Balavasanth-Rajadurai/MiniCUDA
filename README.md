# MiniCUDA
A GPU designed using HDL 

A work in progress to make a more complete GPU

**GPU_v1:**  The design supports Branch divergence.

**GPU_v2:**  The design supports Branch divergence + Branch synchronization.

# A description of the **GPU_v1** and **GPU_v2**

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


The base design has been inspired by https://github.com/adam-maj/tiny-gpu
