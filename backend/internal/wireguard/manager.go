package wireguard

import (
	"fmt"
	"os/exec"
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
