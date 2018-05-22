# LPDDR_model

## Quick Start
Please add following lines to your VIM (~/.vimrc) config file to enable autocmd.

```
function! SetupVerilogEnvironment()
    map <F5> :! iverilog -o %:r.vvp %:r.v mobile_ddr2.v && vvp -n %:r.vvp <ENTER>
    "map <F5> :! iverilog -o %:r.vvp %:r.v mobile_ddr2.v && vvp %:r.vvp && gtkwave %:r.vcd <ENTER>
endfunction

if has("autocmd")
    autocmd Filetype verilog call SetupVerilogEnvironment()
endif
```

To view waveform, use GTKWave 
```
gtkwave tb.vcd
```
