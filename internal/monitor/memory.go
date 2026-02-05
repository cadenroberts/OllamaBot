package monitor

import (
	"io"
	"os"
	"runtime"
	"strconv"
	"sync/atomic"
	"time"
)

type Options struct {
	Interval time.Duration
	Width    int
	Label    string
	StartDelay time.Duration
	Enabled  bool
}

const (
	defaultInterval = 1 * time.Second
	defaultWidth    = 24
	defaultStartDelay = 750 * time.Millisecond
)

var disabled atomic.Bool

func Disable() {
	disabled.Store(true)
}

func StartMemoryGraph(out io.Writer, opts Options) func() {
	if disabled.Load() {
		return func() {}
	}
	if out == nil {
		out = os.Stderr
	}
	if opts.Interval <= 0 {
		opts.Interval = defaultInterval
	}
	if opts.Width <= 0 {
		opts.Width = defaultWidth
	}
	if opts.StartDelay <= 0 {
		opts.StartDelay = defaultStartDelay
	}
	if opts.Label == "" {
		opts.Label = "mem"
	}

	if !opts.Enabled {
		return func() {}
	}
	if os.Getenv("OBOT_MEM_GRAPH") == "0" {
		return func() {}
	}

	if !isTerminal(out) {
		return func() {}
	}

	stopCh := make(chan struct{})
	doneCh := make(chan struct{})

	go func() {
		defer close(doneCh)
		printed := false

		if opts.StartDelay > 0 {
			timer := time.NewTimer(opts.StartDelay)
			select {
			case <-timer.C:
			case <-stopCh:
				timer.Stop()
				return
			}
		}

		ticker := time.NewTicker(opts.Interval)
		defer ticker.Stop()

		var lastLen int
		lineBuf := make([]byte, 0, 160)
		barBuf := make([]byte, opts.Width)
		var samples [16]float64
		var sampleIdx int

		for {
			select {
			case <-ticker.C:
				var ms runtime.MemStats
				runtime.ReadMemStats(&ms)

				heapMB := float64(ms.HeapAlloc) / (1024 * 1024)
				sysMB := float64(ms.Sys) / (1024 * 1024)
				ratio := 0.0
				if sysMB > 0 {
					ratio = heapMB / sysMB
					if ratio < 0 {
						ratio = 0
					}
					if ratio > 1 {
						ratio = 1
					}
				}

				samples[sampleIdx%len(samples)] = ratio
				sampleIdx++

				lineBuf = lineBuf[:0]
				lineBuf = append(lineBuf, '\r')
				lineBuf = buildLine(lineBuf, barBuf, opts.Label, heapMB, sysMB, ms.NumGC, ratio, samples[:], sampleIdx)
				lineLen := len(lineBuf) - 1
				if lastLen > lineLen {
					lineBuf = appendSpaces(lineBuf, lastLen-lineLen)
					lineLen = lastLen
				}
				lastLen = lineLen
				printed = true
				_, _ = out.Write(lineBuf)
			case <-stopCh:
				if printed {
					clear := make([]byte, lastLen+2)
					clear[0] = '\r'
					for i := 1; i <= lastLen; i++ {
						clear[i] = ' '
					}
					clear[lastLen+1] = '\r'
					_, _ = out.Write(clear)
				}
				return
			}
		}
	}()

	return func() {
		close(stopCh)
		<-doneCh
	}
}

func buildLine(dst []byte, barBuf []byte, label string, heapMB float64, sysMB float64, gc uint32, ratio float64, samples []float64, sampleIdx int) []byte {
	dst = append(dst, label...)
	dst = append(dst, ' ', '[')
	filled := int(ratio * float64(len(barBuf)))
	if filled < 0 {
		filled = 0
	}
	if filled > len(barBuf) {
		filled = len(barBuf)
	}
	for i := 0; i < len(barBuf); i++ {
		if i < filled {
			barBuf[i] = '#'
		} else {
			barBuf[i] = '-'
		}
	}
	dst = append(dst, barBuf...)
	dst = append(dst, ']', ' ')

	dst = append(dst, "heap="...)
	dst = appendFloat(dst, heapMB)
	dst = append(dst, "MB sys="...)
	dst = appendFloat(dst, sysMB)
	dst = append(dst, "MB gc="...)
	dst = strconv.AppendUint(dst, uint64(gc), 10)
	dst = append(dst, ' ')
	dst = appendSpark(dst, samples, sampleIdx)

	return dst
}

func appendSpark(dst []byte, samples []float64, sampleIdx int) []byte {
	levels := []byte{'.', ':', '*', '#'}
	count := len(samples)
	if count == 0 {
		return dst
	}
	start := sampleIdx - count
	if start < 0 {
		start = 0
	}
	for i := start; i < start+count; i++ {
		value := samples[i%count]
		level := int(value * float64(len(levels)-1))
		if level < 0 {
			level = 0
		}
		if level >= len(levels) {
			level = len(levels) - 1
		}
		dst = append(dst, levels[level])
	}
	return dst
}

func appendFloat(dst []byte, value float64) []byte {
	if value < 10 {
		return strconv.AppendFloat(dst, value, 'f', 2, 64)
	}
	if value < 100 {
		return strconv.AppendFloat(dst, value, 'f', 1, 64)
	}
	return strconv.AppendFloat(dst, value, 'f', 0, 64)
}

func appendSpaces(dst []byte, count int) []byte {
	for i := 0; i < count; i++ {
		dst = append(dst, ' ')
	}
	return dst
}

func isTerminal(out io.Writer) bool {
	file, ok := out.(*os.File)
	if !ok {
		return false
	}
	info, err := file.Stat()
	if err != nil {
		return false
	}
	return (info.Mode() & os.ModeCharDevice) != 0
}
