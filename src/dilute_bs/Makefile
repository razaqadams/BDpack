include ../make.inc

OBJLIBS	 = ../libdlt_bs.a
CMNOBJS += ../common/arry_mod.o 
CMNOBJS += ../common/prcn_mod.o 
CMNOBJS += ../common/strg_mod.o
OBJS	 = inp_dlt.o dcmp_mod.o root_mod.o 
OBJS    += force_mod.o HIEVCalc.o pp_mod.o 
OBJS    += dlt_mod.o
INCS	 = -I ../common/inc
INCS    += -I ./inc
ifeq ($(FCOMP),gfortran)
MOD      = -J ./inc
else ifeq ($(FCOMP),ifort)
MOD      = -module ./inc
endif


all : makeinc $(OBJLIBS)

makeinc:
	if [ ! -d "./inc" ];then     \
                mkdir ./inc;         \
        fi

../libdlt_bs.a : $(OBJS) $(CMNOBJS)
	$(ECHO) making the library: $(OBJLIBS)
	$(AR) $(ARFLAGS) rv ../libdlt_bs.a $?
	$(RANLIB) ../libdlt_bs.a
#	$(MV) ./*.mod ./inc/
#	$(RM) -f $(OBJS)

$(OBJS): %.o: %.$(FEXT)
	$(ECHO) compiling $< using $(COMP)
	$(COMP) $(GLBFLGS) $(GLBINCS) $(INCS) $(MOD) -c $< -o $@
clean :
	$(ECHO) cleaning up in dilute_bs
	$(RM) -f $(OBJS)
