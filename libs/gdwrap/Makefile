MLTK=../..
CC=gcc
#CC=clang
INCDS=-Iinclude -I$(MLTK)/include


DEFINES=-DRELAXEDFATAL
ifdef GDSL_ARCH
UPPER_ARCH = $(shell echo $(GDSL_ARCH) | tr a-z A-Z)
DEFINES+=-DGDSL_$(UPPER_ARCH)
endif
CFLAGS=-c -g3 -std=c11 -pedantic -Wall -Wfatal-errors $(DEFINES) $(INCDS)

LIBRARY=libgdwrap.a
SOURCES=gdwrap.c

all: pre-build $(LIBRARY)

SPRE=src
BPRE=build

BDIRS=$(BPRE)
pre-build:
	mkdir -p $(BDIRS)

OBJECTS=$(addprefix $(BPRE)/, $(SOURCES:.c=.o))

$(LIBRARY): $(OBJECTS)
	ar -r  $@  $(OBJECTS)

$(OBJECTS): $(BPRE)/%.o : $(SPRE)/%.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -rf $(BDIRS) $(LIBRARY)
