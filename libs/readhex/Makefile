MLTK=../..
CC=gcc
#CC=clang
INCDS=-Iinclude -I$(MLTK)/include
CFLAGS=-c -g3 -std=c11 -pedantic -Wall -Wfatal-errors -DRELAXEDFATAL $(INCDS)

LIBRARY=libreadhex.a
SOURCES=readhex.c

all: pre-build $(LIBRARY)

SPRE=src/
BPRE=build/

BDIRS=$(BPRE)
pre-build:
	mkdir -p $(BDIRS)

OBJECTS=$(addprefix $(BPRE), $(SOURCES:.c=.o))

$(LIBRARY): $(OBJECTS)
	ar -r  $@  $(OBJECTS)

$(OBJECTS): $(BPRE)%.o : $(SPRE)%.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -rf $(BDIRS) $(LIBRARY)
