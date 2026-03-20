package wireguard

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os/exec"
	"strings"
	"time"
)

// PeerManager manages WireGuard peers on the local wg0 interface.
type PeerManager interface {
	AddPeer(publicKey, assignedIP string) error
	RemovePeer(publicKey string) error
}

// LocalPeerManager manages peers by executing wg commands locally.
type LocalPeerManager struct {
	iface string
}

func NewLocalPeerManager(iface string) *LocalPeerManager {
	return &LocalPeerManager{iface: iface}
}

func (m *LocalPeerManager) AddPeer(publicKey, assignedIP string) error {
	allowedIPs := fmt.Sprintf("%s/32", assignedIP)
	cmd := exec.Command("wg", "set", m.iface, "peer", publicKey, "allowed-ips", allowedIPs)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("wg set peer: %w: %s", err, out)
	}
	return nil
}

func (m *LocalPeerManager) RemovePeer(publicKey string) error {
	cmd := exec.Command("wg", "set", m.iface, "peer", publicKey, "remove")
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("wg remove peer: %w: %s", err, out)
	}
	return nil
}

// HTTPPeerManager manages peers via a WireGuard gateway admin API.
type HTTPPeerManager struct {
	baseURL string
	client  *http.Client
}

func NewHTTPPeerManager(baseURL string) *HTTPPeerManager {
	return &HTTPPeerManager{
		baseURL: strings.TrimRight(baseURL, "/"),
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
	}
}

func (m *HTTPPeerManager) AddPeer(publicKey, assignedIP string) error {
	body, err := json.Marshal(map[string]string{
		"public_key":  publicKey,
		"assigned_ip": assignedIP,
	})
	if err != nil {
		return fmt.Errorf("marshal add peer request: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, m.baseURL+"/peers", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("create add peer request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := m.client.Do(req)
	if err != nil {
		return fmt.Errorf("add peer request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return fmt.Errorf("add peer failed with status %s", resp.Status)
	}
	return nil
}

func (m *HTTPPeerManager) RemovePeer(publicKey string) error {
	req, err := http.NewRequest(http.MethodDelete, m.baseURL+"/peers/"+url.PathEscape(publicKey), nil)
	if err != nil {
		return fmt.Errorf("create remove peer request: %w", err)
	}

	resp, err := m.client.Do(req)
	if err != nil {
		return fmt.Errorf("remove peer request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return fmt.Errorf("remove peer failed with status %s", resp.Status)
	}
	return nil
}
