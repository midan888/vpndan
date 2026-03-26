package main

import (
	"bytes"
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
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	configDir         = "/config"
	privateKeyPath    = configDir + "/server_private.key"
	publicKeyPath     = configDir + "/server_public.key"
	wireGuardConfPath = "/etc/amnezia/amneziawg/wg0.conf"
	defaultAddress    = "10.0.0.1/24"
	defaultListenPort = "51820"
	defaultAdminAddr  = "127.0.0.1:9080"
)

type gatewayConfig struct {
	Address    string
	ListenPort string
	AdminAddr  string
	UplinkIF   string
	// Amnezia WireGuard obfuscation params
	Jc   int
	Jmin int
	Jmax int
	S1   int
	S2   int
	H1   int64
	H2   int64
	H3   int64
	H4   int64
}

// nodeConfig holds the API registration settings.
// All fields are optional — if API_URL is empty, registration is skipped.
type nodeConfig struct {
	APIURL     string
	NodeSecret string
	NodeName   string
	Country    string
	Host       string
	WGAdminURL string
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
		log.Printf("awg-quick down skipped: %v", err)
	}
	if err := execWGQuick("up"); err != nil {
		log.Fatalf("failed to bring up wg0: %v", err)
	}

	log.Printf("amnezia wireguard gateway ready: public_key=%s uplink=%s admin=%s", publicKey, cfg.UplinkIF, cfg.AdminAddr)

	// Start admin HTTP API
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

	// Node registration + heartbeat (only if API_URL is configured)
	nodeCfg := loadNodeConfig()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	if nodeCfg.APIURL != "" {
		go runNodeAgent(ctx, nodeCfg, cfg, publicKey)
	} else {
		log.Printf("API_URL not set — node registration disabled")
	}

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	cancel()
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()
	_ = httpServer.Shutdown(shutdownCtx)
	_ = execWGQuick("down")
}

// --- Node registration + heartbeat ---

func loadNodeConfig() nodeConfig {
	host := os.Getenv("NODE_HOST")
	return nodeConfig{
		APIURL:     os.Getenv("API_URL"),
		NodeSecret: os.Getenv("NODE_SECRET"),
		NodeName:   os.Getenv("NODE_NAME"),
		Country:    os.Getenv("NODE_COUNTRY"),
		Host:       host,
		WGAdminURL: envOrDefault("WG_ADMIN_URL", fmt.Sprintf("http://%s:9080", host)),
	}
}

func runNodeAgent(ctx context.Context, ncfg nodeConfig, gcfg *gatewayConfig, publicKey string) {
	// Register with central API
	if err := registerNode(ncfg, gcfg, publicKey); err != nil {
		log.Printf("ERROR: node registration failed: %v", err)
		log.Printf("will retry on next heartbeat cycle")
	} else {
		log.Printf("node registered with central API")
	}

	// Heartbeat loop
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Printf("node agent shutting down")
			return
		case <-ticker.C:
			if err := sendHeartbeat(ncfg); err != nil {
				log.Printf("WARN: heartbeat failed: %v — re-registering", err)
				if regErr := registerNode(ncfg, gcfg, publicKey); regErr != nil {
					log.Printf("ERROR: re-registration failed: %v", regErr)
				}
			}
		}
	}
}

func registerNode(ncfg nodeConfig, gcfg *gatewayConfig, publicKey string) error {
	port, _ := strconv.Atoi(gcfg.ListenPort)
	body, err := json.Marshal(map[string]any{
		"name":         ncfg.NodeName,
		"country":      ncfg.Country,
		"host":         ncfg.Host,
		"port":         port,
		"public_key":   publicKey,
		"wg_admin_url": ncfg.WGAdminURL,
		"awg_jc":       gcfg.Jc,
		"awg_jmin":     gcfg.Jmin,
		"awg_jmax":     gcfg.Jmax,
		"awg_s1":       gcfg.S1,
		"awg_s2":       gcfg.S2,
		"awg_h1":       gcfg.H1,
		"awg_h2":       gcfg.H2,
		"awg_h3":       gcfg.H3,
		"awg_h4":       gcfg.H4,
	})
	if err != nil {
		return fmt.Errorf("marshal register body: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, ncfg.APIURL+"/api/v1/nodes/register", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+ncfg.NodeSecret)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return fmt.Errorf("API returned %s", resp.Status)
	}
	return nil
}

func sendHeartbeat(ncfg nodeConfig) error {
	body, err := json.Marshal(map[string]string{"host": ncfg.Host})
	if err != nil {
		return fmt.Errorf("marshal heartbeat: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, ncfg.APIURL+"/api/v1/nodes/heartbeat", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+ncfg.NodeSecret)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return fmt.Errorf("API returned %s", resp.Status)
	}
	return nil
}

// --- WireGuard gateway ---

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
		Jc:         envInt("AWG_JC", 4),
		Jmin:       envInt("AWG_JMIN", 40),
		Jmax:       envInt("AWG_JMAX", 70),
		S1:         envInt("AWG_S1", 0),
		S2:         envInt("AWG_S2", 0),
		H1:         envInt64("AWG_H1", 1928394756),
		H2:         envInt64("AWG_H2", 3847291056),
		H3:         envInt64("AWG_H3", 2938475610),
		H4:         envInt64("AWG_H4", 1029384756),
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

	cmd := exec.Command("sh", "-c", fmt.Sprintf("umask 077 && awg genkey | tee %s | awg pubkey > %s", privateKeyPath, publicKeyPath))
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
Jc = %d
Jmin = %d
Jmax = %d
S1 = %d
S2 = %d
H1 = %d
H2 = %d
H3 = %d
H4 = %d
PostUp = iptables -I FORWARD 1 -i wg0 -o %s -j ACCEPT; iptables -I FORWARD 1 -i %s -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -I POSTROUTING 1 -s 10.0.0.0/24 -o %s -j MASQUERADE; iptables -t mangle -I FORWARD 1 -o %s -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
PostDown = iptables -D FORWARD -i wg0 -o %s -j ACCEPT; iptables -D FORWARD -i %s -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o %s -j MASQUERADE; iptables -t mangle -D FORWARD -o %s -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
`,
		strings.TrimSpace(string(privateKey)),
		cfg.Address, cfg.ListenPort,
		cfg.Jc, cfg.Jmin, cfg.Jmax,
		cfg.S1, cfg.S2,
		cfg.H1, cfg.H2, cfg.H3, cfg.H4,
		cfg.UplinkIF, cfg.UplinkIF, cfg.UplinkIF, cfg.UplinkIF,
		cfg.UplinkIF, cfg.UplinkIF, cfg.UplinkIF, cfg.UplinkIF,
	)

	if err := os.WriteFile(wireGuardConfPath, []byte(content), 0o600); err != nil {
		return fmt.Errorf("write wg0.conf: %w", err)
	}
	return nil
}

func execWGQuick(action string) error {
	cmd := exec.Command("awg-quick", action, "wg0")
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("awg-quick %s: %w: %s", action, err, out)
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

	cmd := exec.Command("awg", "set", "wg0", "peer", req.PublicKey, "allowed-ips", allowedIP)
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

	cmd := exec.Command("awg", "set", "wg0", "peer", publicKey, "remove")
	if out, err := cmd.CombinedOutput(); err != nil {
		http.Error(w, fmt.Sprintf("failed to remove peer: %v: %s", err, out), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// --- Helpers ---

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func envInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}

func envInt64(key string, fallback int64) int64 {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil {
			return n
		}
	}
	return fallback
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
