.PHONY: default env clean cleanall chr

CHRUTIL = go-nes/bin/chrutil
SCRCONV = convert-screen.go
NAME = brainfuck
NESCFG = nes_nrom.cfg
CAFLAGS = -g -t nes
LDFLAGS = -C $(NESCFG) --dbgfile bin/$(NAME).dbg -m bin/$(NAME).map

SOURCES = main.asm \
		  keyboard.asm \
		  state-help.asm \
		  state-input.asm \
		  state-menu.asm \
		  state-load.asm \
		  state-clear.asm \
		  state-run.asm \
		  state-done.asm \
		  state-compile.asm \
		  help.i \
		  border.i

CHR = font.chr \
	  brain.chr \
	  eggplant.chr

default: env bin/$(NAME).nes
env: $(CHRUTIL) bin/
bin/:
	-mkdir bin

clean:
	-rm bin/* *.chr *.i

cleanall: clean
	-rm images/*.bmp

bin/$(NAME).nes: bin/main.o
	ld65 $(LDFLAGS) -o $@ $^

bin/main.o: $(SOURCES) $(CHR)
	ca65 $(CAFLAGS) -o $@ main.asm

images/%.bmp: images/%.aseprite
	aseprite -b $< --save-as $@

border.i: layouts/screens.tmx
	go run convert-screen.go --layer border --fill 0 $< $@

help.i: layouts/screens.tmx
	go run convert-screen.go --layer help --fill 0 $< $@

font.chr: images/font.bmp
	$(CHRUTIL) -o $@ $< --tile-count 208

brain.chr: images/brain.bmp
	$(CHRUTIL) -o $@ $< --remove-duplicates --remove-empty --write-ids brain.i

eggplant.chr: images/eggplant.bmp
	$(CHRUTIL) -o $@ $< --remove-duplicates --remove-empty --write-ids brain.i

images/eggplant.bmp: images/logo.aseprite
	aseprite -b $< --layer eggplant --save-as $@

images/brain.bmp: images/logo.aseprite
	aseprite -b $< --layer brain --save-as $@

$(CHRUTIL):
	$(MAKE) -C go-nes/ bin/chrutil$(EXT)
