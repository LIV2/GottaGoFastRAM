PROJECT=gottagofast
PART=XC9572XL-10-VQ64
WORKDIR=tmp
BINDIR=../Binaries
CABLE=usb21
SERIAL=$(shell git rev-parse --short=8 HEAD)

CPLDFITFLAGS=-loc on -slew slow -init low -terminate keeper -nogclkopt -nogtsopt -nogsropt -power std -ignoretspec -optimize speed -keepio -inputs 54 -pterms 25
REV_A_DEFINES=makedefines autoconfig rev_a SERIAL=32'h${SERIAL}
REV_B_DEFINES=makedefines autoconfig rev_b SERIAL=32'h${SERIAL}

.PHONY:	all clean

all:	$(BINDIR)/gottagofast_rev_a.jed $(BINDIR)/gottagofast_rev_b.jed $(BINDIR)/gottagofast_cdtv_rev_a.jed $(BINDIR)/gottagofast_cdtv_rev_b.jed

$(PROJECT).prj:
	@echo verilog work $(PROJECT).v > $@

$(WORKDIR)/$(PROJECT)_rev_a.ngc:	$(PROJECT).v $(PROJECT).prj
	@mkdir $(WORKDIR) || true
	@sed -r "s#^(-top).*#\1 $(PROJECT)#g;s#^(-ofn).*#\1 ..\/$@#g;s#^(-ifn).*#\1 ../$(PROJECT).prj#g;s#^(-define).*#\1 {$(REV_A_DEFINES)}#g" template.xst > $@.xst
	cd $(WORKDIR) && xst -ifn ../$@.xst -ofn $(PROJECT)-xst.log

$(WORKDIR)/$(PROJECT)_rev_b.ngc:	$(PROJECT).v $(PROJECT).prj
	@mkdir $(WORKDIR) || true
	@sed -r "s#^(-top).*#\1 $(PROJECT)#g;s#^(-ofn).*#\1 ..\/$@#g;s#^(-ifn).*#\1 ../$(PROJECT).prj#g;s#^(-define).*#\1 {$(REV_B_DEFINES)}#g" template.xst > $@.xst
	cd $(WORKDIR) && xst -ifn ../$@.xst -ofn $(PROJECT)-xst.log

$(WORKDIR)/$(PROJECT)_6MB_rev_a.ngc:	$(PROJECT).v $(PROJECT).prj
	@mkdir $(WORKDIR) || true
	@sed -r "s#^(-top).*#\1 $(PROJECT)#g;s#^(-ofn).*#\1 ..\/$@#g;s#^(-ifn).*#\1 ../$(PROJECT).prj#g;s#^(-define).*#\1 {$(REV_A_DEFINES) Offer_6M}#g" template.xst > $@.xst
	cd $(WORKDIR) && xst -ifn ../$@.xst -ofn $(PROJECT)-xst.log

$(WORKDIR)/$(PROJECT)_6MB_rev_b.ngc:	$(PROJECT).v $(PROJECT).prj
	@mkdir $(WORKDIR) || true
	@sed -r "s#^(-top).*#\1 $(PROJECT)#g;s#^(-ofn).*#\1 ..\/$@#g;s#^(-ifn).*#\1 ../$(PROJECT).prj#g;s#^(-define).*#\1 {$(REV_B_DEFINES) Offer_6M}#g" template.xst > $@.xst
	cd $(WORKDIR) && xst -ifn ../$@.xst -ofn $(PROJECT)-xst.log

$(WORKDIR)/$(PROJECT)_cdtv_rev_a.ngc:	$(PROJECT).v $(PROJECT).prj
	@mkdir $(WORKDIR) || true
	@sed -r "s#^(-top).*#\1 $(PROJECT)#g;s#^(-ofn).*#\1 ..\/$@#g;s#^(-ifn).*#\1 ../$(PROJECT).prj#g;s#^(-define).*#\1 {$(REV_A_DEFINES) cdtv}#g" template.xst > $@.xst
	cd $(WORKDIR) && xst -ifn ../$@.xst -ofn $(PROJECT)-xst.log

$(WORKDIR)/$(PROJECT)_cdtv_rev_b.ngc:	$(PROJECT).v $(PROJECT).prj
	@mkdir $(WORKDIR) || true
	@sed -r "s#^(-top).*#\1 $(PROJECT)#g;s#^(-ofn).*#\1 ..\/$@#g;s#^(-ifn).*#\1 ../$(PROJECT).prj#g;s#^(-define).*#\1 {$(REV_B_DEFINES) cdtv}#g" template.xst > $@.xst
	cd $(WORKDIR) && xst -ifn ../$@.xst -ofn $(PROJECT)-xst.log


$(WORKDIR)/%.ngd:	$(WORKDIR)/%.ngc $(PROJECT).ucf
	cd $(WORKDIR) && ngdbuild -p $(PART) -uc ../$(PROJECT).ucf ../$< ../$@

$(WORKDIR)/%.vm6:	$(WORKDIR)/%.ngd $(PROJECT).ucf
	cd $(WORKDIR) && cpldfit $(CPLDFITFLAGS) -p $(PART) ../$<

%.jed:	$(WORKDIR)/%.vm6
	hprep6 -i $<

$(BINDIR)/%.jed: %.jed
	cp $< $(BINDIR)

clean:
	- rm -rvf tmp
	- rm -fv *.jed
	- rm -fv *.prj

cleanjeds: 
	- @rm -fv $(BINDIR)/*.jed

flash-reva:	$(PROJECT)_rev_a.jed
	@echo "setMode -bs\n"\
	"setCable -p $(CABLE)\n"\
	"identify\n"\
	"assignfile -p 1 -file $<\n"\
	"erase -p 1\n"\
	"program -p 1\n"\
	"verify -p 1\n"\
	"exit" > batch
	LD_PRELOAD=/opt/Xilinx/usb-driver/libusb-driver.so impact -batch batch
	
flash-reva-cdtv:	$(PROJECT)_cdtv_rev_a.jed
	@echo "setMode -bs\n"\
	"setCable -p $(CABLE)\n"\
	"identify\n"\
	"assignfile -p 1 -file $<\n"\
	"erase -p 1\n"\
	"program -p 1\n"\
	"verify -p 1\n"\
	"exit" > batch
	LD_PRELOAD=/opt/Xilinx/usb-driver/libusb-driver.so impact -batch batch

flash-revb:	$(PROJECT)_rev_b.jed
	@echo "setMode -bs\n"\
	"setCable -p $(CABLE)\n"\
	"identify\n"\
	"assignfile -p 1 -file $<\n"\
	"erase -p 1\n"\
	"program -p 1\n"\
	"verify -p 1\n"\
	"exit" > batch
	LD_PRELOAD=/opt/Xilinx/usb-driver/libusb-driver.so impact -batch batch
	
flash-revb-cdtv:	$(PROJECT)_cdtv_rev_b.jed
	@echo "setMode -bs\n"\
	"setCable -p $(CABLE)\n"\
	"identify\n"\
	"assignfile -p 1 -file $<\n"\
	"erase -p 1\n"\
	"program -p 1\n"\
	"verify -p 1\n"\
	"exit" > batch
	LD_PRELOAD=/opt/Xilinx/usb-driver/libusb-driver.so impact -batch batch
