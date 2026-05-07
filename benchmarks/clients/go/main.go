package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

type result struct {
	Runtime        string  `json:"runtime"`
	Requests       int     `json:"requests"`
	Warmup         int     `json:"warmup"`
	ElapsedMS      float64 `json:"elapsed_ms"`
	RequestsPerSec float64 `json:"requests_per_sec"`
	Bytes          int64   `json:"bytes"`
}

func main() {
	url := flag.String("url", "http://127.0.0.1:3200/payload", "benchmark URL")
	requests := flag.Int("requests", 10000, "measured request count")
	warmup := flag.Int("warmup", 200, "unmeasured warmup request count")
	flag.Parse()

	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.MaxIdleConns = 1024
	transport.MaxIdleConnsPerHost = 1024
	client := &http.Client{Transport: transport}

	for i := 0; i < *warmup; i++ {
		if _, err := issueRequest(client, *url); err != nil {
			fail(err)
		}
	}

	var bytes int64
	started := time.Now()
	for i := 0; i < *requests; i++ {
		n, err := issueRequest(client, *url)
		if err != nil {
			fail(err)
		}
		bytes += n
	}
	elapsedMS := float64(time.Since(started).Microseconds()) / 1000

	enc := json.NewEncoder(os.Stdout)
	if err := enc.Encode(result{
		Runtime:        "go",
		Requests:       *requests,
		Warmup:         *warmup,
		ElapsedMS:      elapsedMS,
		RequestsPerSec: float64(*requests) * 1000 / elapsedMS,
		Bytes:          bytes,
	}); err != nil {
		fail(err)
	}
}

func issueRequest(client *http.Client, url string) (int64, error) {
	response, err := client.Get(url)
	if err != nil {
		return 0, err
	}
	defer response.Body.Close()

	n, err := io.Copy(io.Discard, response.Body)
	if err != nil {
		return 0, err
	}
	if response.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("unexpected status %d", response.StatusCode)
	}
	return n, nil
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
