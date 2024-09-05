transcript on
if ![file isdirectory uk101_iputf_libs] {
	file mkdir uk101_iputf_libs
}

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

###### Libraries for IPUTF cores 
###### End libraries for IPUTF cores 
###### MIF file copy and HDL compilation commands for IPUTF cores 


vcom "C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/UK101_DE0CV/PLL5_25_sim/PLL5_25.vho"

vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/Components/6850/acia6850.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/Components/6821/pia6821.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/UK101/HiresRam.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/UK101_DE0CV/UK101TextDisplay.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/UK101_DE0CV/ProgRam.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/UK101/CharRom.VHD}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/UK101/CegmonRom.VHD}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/UK101/BasicRom.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/UK101/DisplayRam.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/Components/UART/bufferedUART.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/Components/PS2KB/UK101keyboard.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/Components/PS2KB/ps2_intf.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/Components/M6502/T65_Pack.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/UK101_DE0CV/DiskRAM.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/Components/M6502/T65_MCode.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/Components/M6502/T65_ALU.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/Components/M6502/T65.vhd}
vcom -93 -work work {C:/FPGA/Altera/DE0_CV/OSI_Searle_Q17/UK101_DE0CV/uk101.vhd}

