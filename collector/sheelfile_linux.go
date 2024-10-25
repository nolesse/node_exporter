//go:build !noshellfile

package collector

import (
	"fmt"
	"github.com/alecthomas/kingpin/v2"
	"github.com/prometheus/common/expfmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/go-kit/log"
	"github.com/go-kit/log/level"
	"github.com/prometheus/client_golang/prometheus"
)

var (
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
	mtime  *float64
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

	mtimes := make(map[string]time.Duration)
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
			mtime, err := c.execShellFile(path, f.Name(), ch)
			if err != nil {
				errVal++
				level.Error(c.logger).Log("msg", "failed to collect shellfile data", "file", f.Name(), "err", err)
				continue
			}
			mtimes[filepath.Join(path, f.Name())] = mtime
		}
	}
	c.exportMTimes(mtimes, ch)

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

func (c *shellFileCollector) exportMTimes(mtimes map[string]time.Duration, ch chan<- prometheus.Metric) {
	if len(mtimes) == 0 {
		return
	}

	filepaths := make([]string, 0, len(mtimes))
	for path := range mtimes {
		filepaths = append(filepaths, path)
	}
	sort.Strings(filepaths)

	for _, path := range filepaths {
		mtime := float64(mtimes[path])
		if c.mtime != nil {
			mtime = *c.mtime
		}
		ch <- prometheus.MustNewConstMetric(shellFileMtimeDesc, prometheus.GaugeValue, mtime, path)
	}
}

func (c *shellFileCollector) execShellFile(dir, name string, ch chan<- prometheus.Metric) (mtime time.Duration, err error) {
	start := time.Now()
	path := filepath.Join(dir, name)
	cmd := exec.Command("/bin/sh", path)
	output, err := cmd.Output()
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
