set_global_assignment -entity "PLL5_25" -library "lib_PLL5_25" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "PLL5_25" -library "lib_PLL5_25" -name IP_TOOL_VERSION "18.1"
set_global_assignment -entity "PLL5_25" -library "lib_PLL5_25" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_PLL5_25" -name SPD_FILE [file join $::quartus(sip_path) "PLL5_25.spd"]

set_global_assignment -library "lib_PLL5_25" -name MISC_FILE [file join $::quartus(sip_path) "PLL5_25_sim/PLL5_25.vho"]
