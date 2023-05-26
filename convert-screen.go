package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/alexflint/go-arg"
	"github.com/zorchenhimer/go-tiled"
)

type options struct {
	Input string `arg:"positional,required"`
	Output string `arg:"positional,required"`
	Layer string `arg:"-l,--layer" help:"Layer to read.  Defaults to first found."`
	FillTile uint32 `arg:"--fill" default:"0" help:"Tile ID to use when none specified in map"`
}

func main() {
	opts := &options{}
	arg.MustParse(opts)

	err := run(opts)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func run(opt *options) error {
	data, err := tiled.LoadMap(opt.Input)
	if err != nil {
		return fmt.Errorf("Unable to load input file: %w", err)
	}

	if len(data.Layers) == 0 {
		return fmt.Errorf("No layers present in map")
	}

	//length := data.Properties.Width * data.Properties.Height
	layer := data.Layers[0]
	if opt.Layer != "" {
		found := false
		for _, l := range data.Layers {
			if l.Name == opt.Layer {
				layer = l
				found = true
				break
			}
		}

		if !found {
			return fmt.Errorf("Layer not found")
		}
	}

	str := []string{}
	lastTile := 0
	tileCount := 1
	first := true
	var tint int
	for _, t := range layer.Data {
		//fmt.Printf("raw tile value: $%02X [%d]\n", t, t)
		if t == 0 {
			t = opt.FillTile+1
		}
		t -= 1
		tint = int(t)
		//fmt.Printf("tint tile value: $%02X [%d]\n", tint, tint)

		if first {
			first = false
			continue
		}

		if tint != lastTile {
			if tileCount != 0 {
				//fmt.Printf("%d $%02X\n", tileCount, tint)
				str = append(str, strconv.Itoa(tileCount))
				str = append(str, strconv.Itoa(lastTile))
			}
			lastTile = tint
			tileCount = 1
		} else {
			tileCount++
		}
	}
	if tileCount != 0 {
		//fmt.Printf("%d $%02X\n", tileCount, tint)
		str = append(str, strconv.Itoa(tileCount))
		str = append(str, strconv.Itoa(tint))
	}

	output, err := os.Create(opt.Output)
	if err != nil {
		return fmt.Errorf("Unable to create output file: %w", err)
	}
	defer output.Close()

	//fmt.Fprintf(output, ".word %d ; length\n", length)
	//fmt.Fprintf(output, ".byte %d, %d ; Width, Height\n", data.Properties.Width, data.Properties.Height)
	fmt.Fprintf(output, ".byte %s\n", strings.Join(str, ", "))

	return nil
}
