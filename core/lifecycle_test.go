package main

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

func availableTCPPort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

func waitForTCP(t *testing.T, addr string, open bool) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", addr, 100*time.Millisecond)
		if err == nil {
			conn.Close()
		}
		if (err == nil) == open {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("TCP %s did not reach open=%v", addr, open)
}

func TestStartFailsWhenProxyPortIsOccupied(t *testing.T) {
	previousHome := constant.Path.HomeDir()
	home := t.TempDir()
	constant.SetHomeDir(home)
	defer constant.SetHomeDir(previousHome)
	occupied, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer occupied.Close()
	port := occupied.Addr().(*net.TCPAddr).Port
	path := filepath.Join(home, "profile.yaml")
	data := fmt.Sprintf("mixed-port: %d\nproxies: []\nproxy-groups: []\nrules: ['MATCH,DIRECT']\n", port)
	if err := os.WriteFile(path, []byte(data), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := setupConfig(&SetupParams{ProfilePath: path, TestURL: "https://example.com"}); err != nil {
		t.Fatal(err)
	}
	defer handleStopListener()
	if handleStartListener() {
		t.Fatal("start succeeded with an occupied proxy port")
	}
	if isRunning {
		t.Fatal("core reported running after listener failure")
	}
	conn, err := net.DialTimeout("tcp", occupied.Addr().String(), time.Second)
	if err != nil {
		t.Fatalf("existing listener was disrupted: %v", err)
	}
	conn.Close()
}

func TestStopAndRestartReleasePorts(t *testing.T) {
	previousHome := constant.Path.HomeDir()
	home := t.TempDir()
	constant.SetHomeDir(home)
	defer constant.SetHomeDir(previousHome)
	dnsPort, controllerPort := availableTCPPort(t), availableTCPPort(t)
	for dnsPort == controllerPort {
		controllerPort = availableTCPPort(t)
	}
	proxyPort := availableTCPPort(t)
	for proxyPort == dnsPort || proxyPort == controllerPort {
		proxyPort = availableTCPPort(t)
	}
	tunnelPort := availableTCPPort(t)
	for tunnelPort == proxyPort || tunnelPort == dnsPort || tunnelPort == controllerPort {
		tunnelPort = availableTCPPort(t)
	}
	profile := fmt.Sprintf("mixed-port: %d\nexternal-controller: 127.0.0.1:%d\ndns:\n  enable: true\n  listen: 127.0.0.1:%d\n  nameserver: [1.1.1.1]\ntunnels:\n  - tcp,127.0.0.1:%d,example.com:80,DIRECT\nproxies: []\nproxy-providers:\n  Local:\n    type: inline\n    payload:\n      - {name: Example, type: ss, server: example.com, port: 443, cipher: aes-128-gcm, password: test}\nproxy-groups:\n  - {name: Main, type: select, use: [Local], proxies: [DIRECT]}\nrules: ['MATCH,DIRECT']\n", proxyPort, controllerPort, dnsPort, tunnelPort)
	path := filepath.Join(home, "profile.yaml")
	if err := os.WriteFile(path, []byte(profile), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := setupConfig(&SetupParams{ProfilePath: path, TestURL: "https://example.com"}); err != nil {
		t.Fatal(err)
	}
	defer handleStopListener()
	if _, ok := tunnel.Proxies()["Main"]; !ok {
		t.Fatal("idle configuration did not load proxy groups")
	}
	if _, ok := tunnel.Providers()["Local"]; !ok {
		t.Fatal("idle configuration did not load proxy providers")
	}
	dnsAddr := fmt.Sprintf("127.0.0.1:%d", dnsPort)
	controllerAddr := fmt.Sprintf("127.0.0.1:%d", controllerPort)
	proxyAddr := fmt.Sprintf("127.0.0.1:%d", proxyPort)
	tunnelAddr := fmt.Sprintf("127.0.0.1:%d", tunnelPort)
	waitForTCP(t, tunnelAddr, false)
	waitForTCP(t, dnsAddr, false)
	waitForTCP(t, controllerAddr, false)
	waitForTCP(t, proxyAddr, false)
	handleStartListener()
	waitForTCP(t, tunnelAddr, true)
	waitForTCP(t, dnsAddr, true)
	waitForTCP(t, controllerAddr, true)
	waitForTCP(t, proxyAddr, true)
	handleStopListener()
	waitForTCP(t, dnsAddr, false)
	waitForTCP(t, controllerAddr, false)
	waitForTCP(t, proxyAddr, false)
	waitForTCP(t, tunnelAddr, false)
	if _, err := setupConfig(&SetupParams{ProfilePath: path, TestURL: "https://example.com"}); err != nil {
		t.Fatal(err)
	}
	waitForTCP(t, dnsAddr, false)
	waitForTCP(t, controllerAddr, false)
	waitForTCP(t, tunnelAddr, false)
	handleStartListener()
	waitForTCP(t, dnsAddr, true)
	waitForTCP(t, controllerAddr, true)
	waitForTCP(t, tunnelAddr, true)
	waitForTCP(t, proxyAddr, true)
}
