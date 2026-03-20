package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	configDir         = "/config"
	privateKeyPath    = configDir + "/server_private.key"
	publicKeyPath     = configDir + "/server_public.key"
	wireGuardConfPath = "/etc/wireguard/wg0.conf"
	defaultAddress    = "10.0.0.1/24"
	defaultListenPort = "51820"
	defaultAdminAddr  = "127.0.0.1:9080"
)

type gatewayConfig struct {
	Address    string
	ListenPort string
	AdminAddr  string
	UplinkIF   string
}

type server struct {
	mu sync.Mutex
}

type peerRequest struct {
	PublicKey  string `json:"public_key"`
	AssignedIP string `json:"assigned_ip"`
}

func main() {
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)

	cfg, err := loadConfig()
	if err != nil {
		log.Fatalf("failed to load gateway config: %v", err)
	}

	publicKey, err := ensureKeys()
	if err != nil {
		log.Fatalf("failed to ensure keys: %v", err)
	}

	if err := os.MkdirAll(filepath.Dir(wireGuardConfPath), 0o700); err != nil {
		log.Fatalf("failed to create wireguard directory: %v", err)
	}

	if err := writeWGConfig(cfg); err != nil {
		log.Fatalf("failed to write wireguard config: %v", err)
	}

	if err := execWGQuick("down"); err != nil {
		log.Printf("wg-quick down skipped: %v", err)
	}
	if err := execWGQuick("up"); err != nil {
		log.Fatalf("failed to bring up wg0: %v", err)
	}

	log.Printf("wireguard gateway ready: public_key=%s uplink=%s admin=%s", publicKey, cfg.UplinkIF, cfg.AdminAddr)

	s := &server{}
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{
			"status":     "ok",
			"public_key": publicKey,
		})
	})
	mux.HandleFunc("/peers", s.handlePeers)
	mux.HandleFunc("/peers/", s.handlePeerByKey)

	httpServer := &http.Server{
		Addr:              cfg.AdminAddr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("admin api failed: %v", err)
		}
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = httpServer.Shutdown(ctx)
	_ = execWGQuick("down")
}

func loadConfig() (*gatewayConfig, error) {
	uplink := os.Getenv("WG_UPLINK_IFACE")
	if uplink == "" {
		out, err := exec.Command("sh", "-c", "ip -4 route show default | awk '{print $5; exit}'").Output()
		if err != nil {
			return nil, fmt.Errorf("detect uplink interface: %w", err)
		}
		uplink = strings.TrimSpace(string(out))
	}
	if uplink == "" {
		return nil, fmt.Errorf("WG_UPLINK_IFACE is required when uplink auto-detection fails")
	}

	cfg := &gatewayConfig{
		Address:    envOrDefault("WG_ADDRESS", defaultAddress),
		ListenPort: envOrDefault("WG_LISTEN_PORT", defaultListenPort),
		AdminAddr:  envOrDefault("WG_ADMIN_ADDR", defaultAdminAddr),
		UplinkIF:   uplink,
	}
	return cfg, nil
}

func ensureKeys() (string, error) {
	if err := os.MkdirAll(configDir, 0o700); err != nil {
		return "", fmt.Errorf("create config dir: %w", err)
	}

	if fileExists(privateKeyPath) && fileExists(publicKeyPath) {
		pub, err := os.ReadFile(publicKeyPath)
		if err != nil {
			return "", fmt.Errorf("read public key: %w", err)
		}
		return strings.TrimSpace(string(pub)), nil
	}

	cmd := exec.Command("sh", "-c", fmt.Sprintf("umask 077 && wg genkey | tee %s | wg pubkey > %s", privateKeyPath, publicKeyPath))
	if out, err := cmd.CombinedOutput(); err != nil {
		return "", fmt.Errorf("generate keys: %w: %s", err, out)
	}

	pub, err := os.ReadFile(publicKeyPath)
	if err != nil {
		return "", fmt.Errorf("read generated public key: %w", err)
	}
	return strings.TrimSpace(string(pub)), nil
}

func writeWGConfig(cfg *gatewayConfig) error {
	privateKey, err := os.ReadFile(privateKeyPath)
	if err != nil {
		return fmt.Errorf("read private key: %w", err)
	}

	content := fmt.Sprintf(`[Interface]
PrivateKey = %s
Address = %s
ListenPort = %s
PostUp = iptables -I FORWARD 1 -i wg0 -o %s -j ACCEPT; iptables -I FORWARD 1 -i %s -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -I POSTROUTING 1 -s 10.0.0.0/24 -o %s -j MASQUERADE; iptables -t mangle -I FORWARD 1 -o %s -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
PostDown = iptables -D FORWARD -i wg0 -o %s -j ACCEPT; iptables -D FORWARD -i %s -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o %s -j MASQUERADE; iptables -t mangle -D FORWARD -o %s -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
`, strings.TrimSpace(string(privateKey)), cfg.Address, cfg.ListenPort, cfg.UplinkIF, cfg.UplinkIF, cfg.UplinkIF, cfg.UplinkIF, cfg.UplinkIF, cfg.UplinkIF, cfg.UplinkIF, cfg.UplinkIF)

	if err := os.WriteFile(wireGuardConfPath, []byte(content), 0o600); err != nil {
		return fmt.Errorf("write wg0.conf: %w", err)
	}
	return nil
}

func execWGQuick(action string) error {
	cmd := exec.Command("wg-quick", action, "wg0")
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("wg-quick %s: %w: %s", action, err, out)
	}
	return nil
}

func (s *server) handlePeers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.NotFound(w, r)
		return
	}

	var req peerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json body", http.StatusBadRequest)
		return
	}
	if req.PublicKey == "" || req.AssignedIP == "" {
		http.Error(w, "public_key and assigned_ip are required", http.StatusBadRequest)
		return
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	allowedIP := req.AssignedIP
	if !strings.Contains(allowedIP, "/") {
		allowedIP += "/32"
	}

	cmd := exec.Command("wg", "set", "wg0", "peer", req.PublicKey, "allowed-ips", allowedIP)
	if out, err := cmd.CombinedOutput(); err != nil {
		http.Error(w, fmt.Sprintf("failed to add peer: %v: %s", err, out), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
}

func (s *server) handlePeerByKey(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.NotFound(w, r)
		return
	}

	publicKeyEncoded := strings.TrimPrefix(r.URL.Path, "/peers/")
	publicKey, err := url.PathUnescape(publicKeyEncoded)
	if err != nil || publicKey == "" {
		http.Error(w, "invalid peer key", http.StatusBadRequest)
		return
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	cmd := exec.Command("wg", "set", "wg0", "peer", publicKey, "remove")
	if out, err := cmd.CombinedOutput(); err != nil {
		http.Error(w, fmt.Sprintf("failed to remove peer: %v: %s", err, out), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
