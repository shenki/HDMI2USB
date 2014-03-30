# HDMI2USB Xilinx FPGA bitstream generation
# 2014 Joel Stanley <joel@jms.id.au>

# Lists the input Verilog and VHDL files, so we can
# trigger a rebuild when they change
-include hdl.mk

PART	:= xc6slx45-csg324-3
PROJECT	:= hdmi2usb

all: $(PROJECT).bit

ifndef XILINX
	@echo "Xilinx environment variable is not set. Ensure you have"
	@echo "installed Xilinx ISE and have sourced settings64.sh from"
	@echo "the install location."
endif

$(PROJECT).ngc: ise/$(PROJECT).xst ise/$(PROJECT).prj $(HDL)
	xst -intstyle ise -filter ise/iseconfig/filter.filter -ifn $<

$(PROJECT).ngd: $(PROJECT).ngc ucf/$(PROJECT).ucf
	ngdbuild -dd _ngo -sd ipcore_dir -nt timestamp -p $(PART) \
		-uc ucf/$(PROJECT).ucf $< $@

# TODO(JS): why is logic_opt off?
# TODO(JS): I didn't set options that the help text indicated
# were being set to their defaults. Is this OK?
# TODO(JS): Enabled multi-threading. Is this OK?
$(PROJECT)_map.ncd: $(PROJECT).ngd
	map -p $(PART) -logic_opt off -ol high -xe n -register_duplication off \
		-mt 2 -pr b -o $@ $< $(PROJECT).pcf

# TODO(JS): Enabled multi-threading. Is this OK?
$(PROJECT).ncd: $(PROJECT)_map.ncd $(PROJECT).pcf
	# par foo_map.ncd foo.ncd foo.pcf
	par -ol high -mt 4 $< $@ $(PROJECT).pcf

$(PROJECT).twr: $(PROJECT).ncd $(PROJECT).pcf
	# tcre foo.ncd -o foo.twr foo.pcf
	trce -v 3 -s 3 -n 3 -fastpaths $< -o $@ $(PROJECT).pcf

$(PROJECT).bit: $(PROJECT).ncd
	bitgen -f ise/hdmi2usb.ut $<

# TODO(JS): Finish and test this
program: $(PROJECT).bit
	impact -b $< -port auto -mode bscan -autoassign

clean:
	$(RM) *.bgn *.ngc *.svf *.ngd *.bit *.twr *.ncd *.xrpt
	$(RM) -rf _xmsgs/ xst/

.PHONY: all clean help
