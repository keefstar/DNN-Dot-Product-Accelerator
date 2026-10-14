
# DNN Dot-Product Accelerator | RTL-to-Layout Implementation

A digital IC project taking a SystemVerilog dot-product accelerator through functional verification, Cadence Genus synthesis, Cadence Innovus physical implementation, timing closure, physical verification, and timing-aware gate-level simulation.

The accelerator uses four parallel 16-bit multipliers to compute dot products and includes a 64-entry result memory.

![Final routed layout in Cadence Innovus](images/final_routed_layout.png)

*Final routed layout in Cadence Innovus. Measured dimensions: 185.515 × 182.040 µm.*

## Results at a Glance

| Metric | Result |
| --- | ---: |
| Target operating frequency | **500 MHz** (2.0 ns period) |
| Implementation timing constraint | **1.8 ns** |
| Synthesized standard-cell area | **16,828.161 µm²** |
| Tool-reported final floorplan area | **33,703.7958 µm²** |
| Layout ruler dimensions | **185.515 × 182.040 µm** |
| Final setup slack | **+457 ps** |
| Final hold slack | **+5 ps** |
| Clock skew (setup-late analysis) | **32 ps** |
| Final DRC violations | **0** |
| Final connectivity violations | **0** |
| Post-layout test workload | **576 writes + 576 reads** |
| Post-layout functional checks | **1,152 passing checks** |

The standard-cell area and floorplan area represent different measurements. The tool-reported floorplan area is presented separately from the ruler dimensions because the reported values do not produce an identical area when multiplied.

## Functional Verification

The SystemVerilog testbench verifies accelerator behavior against an independently computed reference model.

- Computes reference dot products from accepted input operands and stores the expected **34-bit results** by memory address.
- Compares returned data against the corresponding reference values during block-read operations.
- Exercises all **64 result-memory addresses**, including intermittent `EN_mac` assertion patterns.
- Checks read/write sequencing and valid-data alignment.
- Uses randomized 16-bit operands to exercise the datapath.

Separate testbenches were developed for RTL functional verification and timing-aware gate-level simulation, with adjustments to stimulus timing and reset duration for the latter.

## Synthesis and Physical Implementation

The implementation flow used **Cadence Genus** for logic synthesis and **Cadence Innovus** for floorplanning, placement, clock-tree synthesis (CTS), routing, timing optimization, and physical verification, using the **GPDK45** educational technology environment.

The design targeted **500 MHz operation (2.0 ns clock period)**. A tighter **1.8 ns implementation constraint** was deliberately applied to encourage more aggressive setup-timing optimization and provide additional margin relative to the nominal operating target.

### Timing Progression

| PnR Stage | Setup Slack | Hold Slack |
| --- | ---: | ---: |
| Pre-placement | +158 ps | −436 ps |
| Post-placement / pre-CTS | −10 ps | −433 ps |
| Post-CTS | +27 ps | +16 ps |
| Post-route | +465 ps | +6 ps |
| Final | **+457 ps** | **+5 ps** |

Clock-tree synthesis and subsequent optimization resolved the initial hold violations, improving worst hold slack from **−436 ps** before placement to **+5 ps** at the final stage. Final setup slack was **+457 ps**.

### Clock-Tree Synthesis

![Clock-tree visualization in Cadence Innovus](images/clock_tree.png)

*Clock tree highlighted in the Innovus layout.*

Cadence CCOpt generated a **four-level buffered clock tree** with:

- **755** positive-edge flip-flop sinks
- **253** clock buffers
- **32 ps** setup-late clock skew
- **Zero** reported clock-tree electrical violations

<details>
<summary>Additional CCOpt visualization</summary>

![CCOpt clock-tree detail](images/clock_tree_ccopt.png)

</details>

## Physical Verification and DRC Closure

Initial routing completed without reported DRC or connectivity violations. Subsequent filler-cell insertion eliminated the checked standard-cell gaps but introduced physical-rule and connectivity violations.

The affected routing was corrected using Innovus `ecoRoute`.

| Before Correction | After ECO Routing |
| --- | --- |
| ![Metal-short violation after filler insertion](images/drc_violation_before.png) | ![Corrected layout after ECO routing](images/drc_after_eco_route.png) |

*Example of a filler-related metal-short violation and the corrected routing geometry.*

The final physical verification checks reported:

- **0 DRC violations**
- **0 connectivity violations**

These results reflect the checks performed within the academic Innovus implementation flow, rather than foundry sign-off.

## Post-Layout Verification

A separate SystemVerilog testbench was used for timing-aware gate-level verification following physical implementation.

The testbench extended reset duration to accommodate initialization under simulated delays and adjusted input stimulus timing to account for the **0.5 ns input-delay constraint**, equivalent to one quarter of the nominal 2.0 ns clock period.

![Timing-aware simulation waveform](images/post_layout_waveform.png)

*Gate-level simulation waveform showing signal timing relative to clock edges.*

Across **nine test iterations**, the testbench exercised:

- **576 write operations**
- **576 read operations**
- **1,152 passing functional checks**

One iteration used continuously asserted `EN_mac`, while the remaining iterations varied the enable signal over time.

Expected outputs were calculated using an independent reference computation and compared against the accelerator's returned data.

![Verification transcript](images/verification_transcript.png)

*Simulation transcript documenting the completed verification workload.*

## Repository Guide

| Directory | Contents |
| --- | --- |
| [`rtl/`](rtl/) | SystemVerilog accelerator RTL and multiplier implementation |
| [`verification/`](verification/) | Functional and timing-aware gate-level testbenches |
| [`synthesis/`](synthesis/) | Cadence Genus scripts, timing constraints, and synthesis reports |
| [`pnr/`](pnr/) | Cadence Innovus implementation scripts, timing reports, and physical verification results |
| [`images/`](images/) | Layout, clock-tree, DRC, and simulation screenshots |

## Author

**Kaisaan (Keefee) Rahman**  
University of British Columbia
