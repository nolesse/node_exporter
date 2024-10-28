//go:build !noshellfile

package collector

import (
	"context"
	"fmt"
	"github.com/alecthomas/kingpin/v2"
	"github.com/prometheus/common/expfmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/go-kit/log"
	"github.com/go-kit/log/level"
	"github.com/prometheus/client_golang/prometheus"
)

var (
	shellFileTimeout   = kingpin.Flag("collector.shellfile.timeout", "The maximum timeout for shell file execution.").Default("20").Int64()
	shellFileDirectory = kingpin.Flag("collector.shellfile.directory", "Directory to execute shell files with output metrics.").Default("").String()
	shellFileMtimeDesc = prometheus.NewDesc(
		"node_shellfile_mtime_seconds",
		"Unixtime mtime of shellfiles successfully execute.",
		[]string{"file"},
		nil,
	)
)

type shellFileCollector struct {
	path   string
	logger log.Logger
}

func init() {
	registerCollector("shellfile", defaultEnabled, NewShellFileCollector)
}

func NewShellFileCollector(logger log.Logger) (Collector, error) {
	c := &shellFileCollector{
		path:   *shellFileDirectory,
		logger: logger,
	}
	return c, nil
}

// Update implements the Collector interface.
func (c *shellFileCollector) Update(ch chan<- prometheus.Metric) error {
	// Iterate over files and accumulate their metrics, but also track any
	// parsing errors so an error metric can be reported.
	var errVal float64

	paths, err := filepath.Glob(c.path)
	if err != nil || len(paths) == 0 {
		paths = []string{c.path}
	}

	var mtimes sync.Map
	var lock sync.Mutex
	var wg sync.WaitGroup
	for _, path := range paths {
		files, err := os.ReadDir(path)
		if err != nil && path != "" {
			level.Error(c.logger).Log("msg", "failed to read shellfile collector directory", "path", path, "err", err)
			continue
		}

		for _, f := range files {
			if !strings.HasSuffix(f.Name(), ".sh") {
				continue
			}

			wg.Add(1)
			go func(fileName string) {
				defer func() {
					wg.Done()
					if r := recover(); r != nil {
						fmt.Println("Recovered from panic:", r)
					}
				}()

				mtime, err := c.execShellFile(path, fileName, ch)
				if err != nil {
					lock.Lock()
					defer lock.Unlock()
					errVal++
					level.Error(c.logger).Log("msg", "failed to collect shellfile data", "file", fileName, "err", err)
					return
				}
				mtimes.Store(filepath.Join(path, fileName), mtime)
			}(f.Name())
		}
	}

	wg.Wait()
	c.exportMTimes(&mtimes, ch)

	ch <- prometheus.MustNewConstMetric(
		prometheus.NewDesc(
			"node_shellfile_scrape_error",
			"Number of errors while executing shell files.",
			nil, nil,
		),
		prometheus.GaugeValue, errVal,
	)
	return nil
}

func (c *shellFileCollector) exportMTimes(mtimes *sync.Map, ch chan<- prometheus.Metric) {
	var filepaths []string
	mtimes.Range(func(key, value interface{}) bool {
		filepaths = append(filepaths, fmt.Sprint(key))
		return true
	})
	sort.Strings(filepaths)

	for _, path := range filepaths {
		if mtime, ok := mtimes.Load(path); ok {
			if duration, ok := mtime.(time.Duration); ok {
				ch <- prometheus.MustNewConstMetric(shellFileMtimeDesc, prometheus.GaugeValue, float64(duration), path)
			}
		}
	}
}

func (c *shellFileCollector) execShellFile(dir, name string, ch chan<- prometheus.Metric) (mtime time.Duration, err error) {
	start := time.Now()
	path := filepath.Join(dir, name)
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(*shellFileTimeout)*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "/bin/sh", path)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return
	}

	var parser expfmt.TextParser
	families, err := parser.TextToMetricFamilies(strings.NewReader(string(output)))
	if err != nil {
		return
	}

	if hasTimestamps(families) {
		return mtime, fmt.Errorf("shellfile %q output contains unsupported client-side timestamps, skipping entire file", path)
	}

	for _, mf := range families {
		if mf.Help == nil {
			help := fmt.Sprintf("Metric read from %s", path)
			mf.Help = &help
		}
	}
	for _, mf := range families {
		convertMetricFamily(mf, ch, c.logger)
	}
	return time.Since(start), nil
}
