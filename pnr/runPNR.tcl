# 0) Prep - a) folders to point to the synthesis outputs
set PNR_OUT_FOLDER  /ubc/ece/home/ugrads/r/rkaisaan/Desktop/PROJ3/pnr/output
set SYNTH_OUT_FOLDER /ubc/ece/home/ugrads/r/rkaisaan/Desktop/PROJ3/outputs

# 0) Prep - b) library timing, lef folders
set LIB_FOLDER /ubc/ece/data/cmc2/kits/GPDK45/gsclib045_all_v4.4/gsclib045/timing
set RCTECH_FOLDER /ubc/ece/data/cmc2/kits/GPDK45/gsclib045_all_v4.4/gsclib045/qrc/qx
set LEF_FOLDER /ubc/ece/data/cmc2/kits/GPDK45/gsclib045_all_v4.4/gsclib045/lef

# 0) Prep - c) specifiers for the design, versioning etc
set TOP_LEVEL "mkMACBuff"
set RUN_NAME  "v3"

setMultiCpuUsage -localCpu 1
setDesignMode -process 45 -node "unspecified"

# STAGE 1: DESIGN IMPORT
puts "STAGE 1: DESIGN IMPORT"

set init_lef_file [list "$LEF_FOLDER/gsclib045_tech.lef" "$LEF_FOLDER/gsclib045_macro.lef"]
set init_verilog [list "$SYNTH_OUT_FOLDER/${TOP_LEVEL}_${RUN_NAME}_map.sv"]
set init_top_cell $TOP_LEVEL
set init_pwr_net "VDD"
set init_gnd_net "VSS"
set init_mmmc_file "MMMC.tcl"
init_design

# CHECKPOINT: Uncomment to stop after design import
# return

# STAGE 2: FLOORPLANNING
puts "STAGE 2: FLOORPLANNING"
puts "Starting with aspect ratio=1, utilization=0.7"

# 2a) Floorplanning
setFPlanMode -snapDieGrid manufacturing
setFPlanMode -snapCoreGrid manufacturing

#Change utilization here if timing doesn't meet. Start at 0.7
#Floorplan: {aspect ratio, utilization, margins on [Left Bottom Right Top]
floorPlan -site CoreSite -r 1 0.60 8 8 8 8
# CHECKPOINT
# return

# STAGE 3: POWER DISTRIBUTION NETWORK
puts "STAGE 3: POWER DISTRIBUTION NETWORK"

# 3a) connecting the global power nets to the power nets on gates/tie-hi or tie-lo
globalNetConnect VDD -type pgpin -pin VDD -instanceBasename * -hierarchicalInstance {}
globalNetConnect VDD -type tiehi -instanceBasename * -hierarchicalInstance {}
globalNetConnect VSS -type pgpin -pin VSS -instanceBasename * -hierarchicalInstance {}
globalNetConnect VSS -type tielo -instanceBasename * -hierarchicalInstance {}

# 3b) Adding the power ring - Metal7 and Metal8, thickness 1.8um
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 \
    -skip_crossing_trunks "none" -stacked_via_top_layer "Metal11" -stacked_via_bottom_layer "Metal1" \
    -via_using_exact_crossover_size 1 -orthogonal_only true \
    -skip_via_on_pin {standardcell} -skip_via_on_wire_shape {noshape}

addRing -nets [list "VDD" "VSS"] -type core_rings -follow "core" \
    -layer {top "Metal7" bottom "Metal7" left "Metal8" right "Metal8"} \
    -width {top 1.8 bottom 1.8 left 1.8 right 1.8} \
    -spacing {top 0.45 bottom 0.45 left 0.45 right 0.45} \
    -offset {top 1.8 bottom 1.8 left 1.8 right 1.8} \
    -center 0 -threshold 0 -jog_distance 0 -snap_wire_center_to_grid "None"

# 3c) sroute for making the horizontal power tracks
setSrouteMode -viaConnectToShape {noshape}

sroute -connect {blockPin padPin padRing corePin floatingStripe} \
    -layerChangeRange {Metal1(1) Metal8(8)} \
    -blockPinTarget {nearestTarget} -padPinPortConnect {allPort oneGeom} \
    -padPinTarget {nearestTarget} -corePinTarget {firstAfterRowEnd} \
    -floatingStripeTarget {blockring padring ring stripe ringpin blockpin followpin} \
    -allowJogging 1 -crossoverViaLayerRange {Metal1(1) Metal11(11)} \
    -nets {VDD VSS} -allowLayerChange 1 -blockPin useLef \
    -targetViaLayerRange {Metal1(1) Metal11(11)}

# 3d) Adding power stripes
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false \
    -rows_without_stripes_only false -extend_to_closest_target none \
    -stop_at_last_wire_for_area false -partial_set_thru_domain false \
    -ignore_nondefault_domains false -trim_antenna_back_to_shape none \
    -spacing_type edge_to_edge -spacing_from_block 0 \
    -stripe_min_length stripe_width -stacked_via_top_layer Metal11 \
    -stacked_via_bottom_layer Metal1 -via_using_exact_crossover_size false \
    -split_vias false -orthogonal_only true \
    -allow_jog {padcore_ring block_ring} \
    -skip_via_on_pin {standardcell} -skip_via_on_wire_shape {noshape}

addStripe -nets [list "VDD" "VSS"] -layer "Metal8" -direction vertical \
    -width 1.8 -spacing 0.45 -number_of_sets 4 -start_from left -start_offset 3 \
    -switch_layer_over_obs false -max_same_layer_jog_length 2 \
    -padcore_ring_top_layer_limit Metal11 -padcore_ring_bottom_layer_limit Metal1 \
    -block_ring_top_layer_limit Metal11 -block_ring_bottom_layer_limit Metal1 \
    -use_wire_group 0 -snap_wire_center_to_grid None

# CHECKPOINT:
#return

# STAGE 4: PIN PLACEMENT

puts "STAGE 4: PIN PLACEMENT (Metal3)"
setPinAssignMode -pinEditInBatch true

# LEFT SIDE PINS - FULL HEIGHT 0 to 179.77um
# mac interface - top quarter (0 to ~45um)
editPin -snap MGRID -fixOverlap 1 -spreadDirection clockwise \
    -side Left -layer 3 -spreadType range -start 0 5.0 -end 0 115.0 \
    -pin {EN_mac RDY_mac mac_vectA_* mac_vectB_*}

# CLK/RST_N - TRUE MIDDLE (~80-95um, centered around 87.5um)
editPin -snap MGRID -fixOverlap 1 -spreadDirection clockwise \
    -side Left -layer 3 -spreadType range -start 0 118.0 -end 0 122.0 \
    -pin {CLK RST_N}

# blockRead interface - third quarter (~105-120um)
editPin -snap MGRID -fixOverlap 1 -spreadDirection clockwise \
    -side Left -layer 3 -spreadType range -start 0 126.0 -end 0 130.0 \
    -pin {EN_blockRead RDY_blockRead}

# memVal interface - bottom quartZer (130 to 179.77um = 50um range!)
editPin -snap MGRID -fixOverlap 1 -spreadDirection clockwise \
    -side Left -layer 3 -spreadType range -start 0 132.0 -end 0 170.0 \
    -pin {VALID_memVal memVal_data*}

# RIGHT side — use core right edge X
# writeMem band
editPin -pinWidth 0.08 -pinDepth 0.25 -snap MGRID -fixOverlap 1 -spreadDirection counterclockwise \
  -side Right -layer 3 -spreadType range -start 166.965 12.0 -end 166.965 75.0 \
  -pin {EN_writeMem writeMem_addr* writeMem_val*}

# readMem band
editPin -pinWidth 0.08 -pinDepth 0.25 -snap MGRID -fixOverlap 1 -spreadDirection counterclockwise \
  -side Right -layer 3 -spreadType range -start 166.965 95.0 -end 166.965 160.0 \
  -pin {EN_readMem readMem_addr* readMem_val*}

setPinAssignMode -pinEditInBatch false

puts "\nPre-place timing analysis..."
timeDesign -reportOnly -prePlace -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_prePlace" -outDir reports
timeDesign -reportOnly -prePlace -hold -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_prePlace_hold" -outDir reports

report_timing -nworst 5 > ./reports/${TOP_LEVEL}_prePlace.rpt

saveDesign chkpts/${TOP_LEVEL}_prePlace
dbGet top.fPlan.area > ./reports/${TOP_LEVEL}_preCTS_area.rpt

puts "\n*** CHECK FLOORPLAN IN GUI ***"
puts "*** Verify pin placement matches schematic ***"
puts "*** Check pre-place timing report ***"

#SCREENSHOT1
# CHECKPOINT:
#return 


# STAGE 5: PLACEMENT
puts "STAGE 5: PLACEMENT"


createBasicPathGroups -expanded 

setPlaceMode -place_detail_use_check_drc true
set_dont_use [get_lib_cells *BUFX2*] true

place_opt_design

# Fixing any overlaps on the cells and fixing fanouts
addTieHiLo -cell {TIEHI TIELO} -prefix LTIE

setOptMode -fixFanoutLoad true
optDesign -preCTS
optDesign -preCTS -incr

puts "\nPost-place/Pre-CTS timing analysis..."
timeDesign -reportOnly -preCTS -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_preCTS" -outDir reports
timeDesign -reportOnly -preCTS -hold -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_preCTS_hold" -outDir reports

report_timing -nworst 5 > ./reports/${TOP_LEVEL}_preCTS.rpt
report_area -detail > ./reports/${TOP_LEVEL}_preCTS_area.rpt


saveDesign chkpts/${TOP_LEVEL}_preCTS

puts "\n*** CHECK PLACEMENT TIMING ***"
puts "*** Setup slack should be < 100ps ***"
puts "*** Utilization should be < 90% ***"
puts "*** If not meeting, reduce utilization and restart from floorplan ***"
# SCREENSHOT 2:
# CHECKPOINT: 
#return


# STAGE 6: CLOCK TREE SYNTHESIS

puts "STAGE 6: CLOCK TREE SYNTHESIS"
reset_ccopt_config

# Update constraint mode with modified SDC (no clock latency/uncertainty)
update_constraint_mode -name cmFunc -sdc_files "$SYNTH_OUT_FOLDER/mkMACBuff_cts.sdc"

# Setting the clock tree root
set_ccopt_property cts_is_sdc_clock_root -pin CLK true
create_ccopt_clock_tree -name CLK -source CLK -no_skew_group
set_ccopt_property clock_period -pin CLK [lindex [get_db clocks .period] 0]

# CTS parameters - max_fanout and target_max_trans should be 1/8 of clock cycle
# For 500MHz (2ns period): 2ns / 8 = 0.25ns = 250ps
set_ccopt_property max_fanout 4
set_ccopt_property target_max_trans 0.25

set_ccopt_property buffer_cells {CLKBUFX2 CLKBUFX3 CLKBUFX4 CLKBUFX8 CLKBUFX12 CLKBUFX16}

# Route type for clock tree - Metal4 to Metal7
create_route_type -name CLKRouteType -top_preferred_layer Metal7 -bottom_preferred_layer Metal4
set_ccopt_property route_type CLKRouteType

# Skew group to balance clock
create_ccopt_skew_group -name CLK/cmFunc -sources CLK -auto_sinks
set_ccopt_property include_source_latency -skew_group CLK/cmFunc true
set_ccopt_property extracted_from_clock_name -skew_group CLK/cmFunc CLK
set_ccopt_property extracted_from_constraint_mode_name -skew_group CLK/cmFunc cmFunc
set_ccopt_property extracted_from_delay_corners -skew_group CLK/cmFunc {dc_lsMax_rcWorst dc_lsMin_rcBest}

puts "\nChecking CTS convergence..."
check_ccopt_clock_tree_convergence

puts "\nBuilding clock tree..."
ccopt_design -cts

puts "\nOptimizing post-CTS..."
optDesign -postCTS
optDesign -postCTS -hold 

puts "\nPost-CTS timing analysis..."
timeDesign -reportOnly -postCTS -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_postCTS" -outDir reports
timeDesign -reportOnly -postCTS -hold -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_postCTS_hold" -outDir reports
report_timing -nworst 5 > ./reports/${TOP_LEVEL}_postCTS.rpt
report_area -detail > ./reports/${TOP_LEVEL}_postCTS_area.rpt


saveDesign chkpts/${TOP_LEVEL}_postCTS

puts "\n*** CHECK POST-CTS TIMING ***"
puts "*** Review clock tree using: Clock->(ccopt...)> apply ***"
puts "*** Check setup and hold timing ***"

# SCREENSHOT 3:
# CHECKPOINT: 
#return


# STAGE 7: ROUTING
puts "STAGE 7: ROUTING"

# Routing parameters - top layer Metal10, timing/SI driven, antenna cells
setNanoRouteMode -routeInsertAntennaDiode 1 -routeAntennaCellName "ANTENNA"
setNanoRouteMode -routeWithTimingDriven 1 -routeWithSiDriven 1
setNanoRouteMode -drouteAutoStop 0 -drouteEndIteration 4
setNanoRouteMode -routeTopRoutingLayer 10

puts "\nPerforming global and detail routing..."
routeDesign -globalDetail -viaOpt -wireOpt

puts "\nOptimizing post-route for setup and hold..."
setAnalysisMode -analysisType onChipVariation -cppr both
optDesign -postRoute -setup -hold 

puts "\nPost-route timing analysis..."
timeDesign -reportOnly -postRoute -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_postRoute" -outDir reports
timeDesign -reportOnly -postRoute -hold -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_postRoute_hold" -outDir reports
report_timing -nworst 5 > ./reports/${TOP_LEVEL}_postRoute.rpt
report_timing -early -max_paths 5 > ./reports/${TOP_LEVEL}_postRoute_hold.rpt
report_area -detail > ./reports/${TOP_LEVEL}_postRoute_area.rpt


saveDesign chkpts/${TOP_LEVEL}_postRoute

puts "\n*** CHECK POST-ROUTE TIMING ***"
puts "*** Both setup and hold should be met ***"
puts "*** Verify DRC and connectivity ***"

# CHECKPOINT:
#return


# PRE-STAGE 8: CAPTURE BEFORE STATE FOR REPORT
puts "CAPTURING PRE-FILLER STATE"

#JUST AFTER ROUTING: 
# Verify DRC - already captured in terminal, but let's save to file too
verify_drc -report reports/verify_drc_BEFORE.rpt
# Verify connectivity
verify_connectivity -report reports/verify_connectivity_BEFORE.rpt
# Check filler gaps at different thresholds
checkFiller -reportGap 0.2 > reports/checkFiller_0.2_BEFORE.rpt
checkFiller -reportGap 0.4 > reports/checkFiller_0.4_BEFORE.rpt
checkFiller -reportGap 2.0 > reports/checkFiller_2.0_BEFORE.rpt

puts "\n*** BEFORE STATE CAPTURED ***"
puts "*** Review violation browser and take screenshots ***"
puts "*** Then continue to Stage 8 ***"

# CHECKPOINT:
#return


# STAGE 8: FILLER CELLS AND FINAL VERIFICATION

puts "STAGE 8: FILLER CELLS & FINAL VERIFICATION"

# Making gaps 2x column by moving stdcells around
puts "\nAdding filler gaps..."
addFillerGap 0.4 -effort high
checkFiller -reportGap 0.2

# Adding filler cells
puts "\nAdding filler cells..."
addFiller -cell {DECAP8 DECAP10} -prefix FILLER1 -doDRC -fitGap
addFiller -cell {DECAP2 DECAP3} -prefix FILLER2 -doDRC -fitGap
#This should introduce DRC Violation?
# ECO routing to fix any issues
verify_drc -report reports/verify_drc_MIDDLE.rpt
verify_connectivity -report reports/verify_connectivity_MIDDLE.rpt
#return
puts "\nECO routing..."
ecoRoute 
verify_drc
ecoRoute -fix_drc

puts "\nFinal timing analysis..."
timeDesign -reportOnly -postRoute -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_final" -outDir reports
timeDesign -reportOnly -postRoute -hold -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_final_hold" -outDir reports


report_timing -nworst 5 > ./reports/${TOP_LEVEL}_final.rpt
report_timing -early -max_paths 5 > ./reports/${TOP_LEVEL}_final_hold.rpt
report_area -detail > ./reports/${TOP_LEVEL}_final_area.rpt

saveDesign chkpts/${TOP_LEVEL}_final

puts "\n*** FINAL CHECKS ***"
puts "*** Verify DRC and connectivity ***"

# CHECKPOINT: Stop before final outputs
#return

# POST-STAGE 8: CAPTURE AFTER STATE FOR REPORT

puts "CAPTURING POST-FILLER STATE"

# Verify DRC - should be clean now
verify_drc -report reports/verify_drc_AFTER.rpt

# Verify connectivity
verify_connectivity -report reports/verify_connectivity_AFTER.rpt

# Check filler gaps - should be minimal/none
checkFiller -reportGap 0.2 > reports/checkFiller_0.2_AFTER.rpt
checkFiller -reportGap 0.4 > reports/checkFiller_0.4_AFTER.rpt
checkFiller -reportGap 2.0 > reports/checkFiller_2.0_AFTER.rpt

puts "*** Compare BEFORE vs AFTER reports ***"
# STAGE 9: FINAL OUTPUTS
puts "STAGE 9: GENERATING OUTPUTS"

verify_drc
verify_connectivity
checkFiller -reportGap 0.2
checkFiller -reportGap 0.4

saveNetlist "$PNR_OUT_FOLDER/${TOP_LEVEL}_pnr.v" -excludeLeafCell

timeDesign -postRoute -reportOnly
write_sdf -max_view av_lsMax_rcWorst_cmFunc -typ_view av_lsMax_rcWorst_cmFunc \
    -recompute_delay_calc -edges noedge -splitsetuphold -remashold \
    -splitrecrem -min_period_edges both "$PNR_OUT_FOLDER/${TOP_LEVEL}_pnr.sdf"

puts "PNR FLOW COMPLETE!"
