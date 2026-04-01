package email

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
)

type Sender interface {
	SendCode(to, code string) error
	SendAccountDeleted(to string) error
}

type ResendSender struct {
	apiKey string
	from   string
}

func NewResendSender(apiKey, from string) *ResendSender {
	return &ResendSender{apiKey: apiKey, from: from}
}

type resendRequest struct {
	From    string `json:"from"`
	To      []string `json:"to"`
	Subject string `json:"subject"`
	HTML    string `json:"html"`
}

func (r *ResendSender) SendCode(to, code string) error {
	body := resendRequest{
		From:    r.from,
		To:      []string{to},
		Subject: "Your VPN Dan login code",
		HTML: fmt.Sprintf(
			`<div style="font-family:sans-serif;max-width:400px;margin:0 auto;text-align:center;padding:40px 20px">
				<h2 style="color:#1a1a2e">Your login code</h2>
				<p style="font-size:36px;font-weight:bold;letter-spacing:8px;color:#7c3aed;margin:24px 0">%s</p>
				<p style="color:#666;font-size:14px">This code expires in 10 minutes.</p>
				<p style="color:#999;font-size:12px;margin-top:24px">If you didn't request this code, you can safely ignore this email.</p>
			</div>`, code),
	}

	jsonBody, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("marshal email request: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, "https://api.resend.com/emails", bytes.NewReader(jsonBody))
	if err != nil {
		return fmt.Errorf("create email request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("send email: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("resend API error: status %d", resp.StatusCode)
	}

	return nil
}

func (r *ResendSender) SendAccountDeleted(to string) error {
	body := resendRequest{
		From:    r.from,
		To:      []string{to},
		Subject: "Your VPN Dan account has been deleted",
		HTML: `<div style="font-family:sans-serif;max-width:400px;margin:0 auto;text-align:center;padding:40px 20px">
				<h2 style="color:#1a1a2e">Account Deleted</h2>
				<p style="color:#333;font-size:16px;margin:24px 0">Your VPN Dan account and all associated data have been permanently deleted.</p>
				<p style="color:#666;font-size:14px">If you did not request this, please contact us immediately at support@vpndan.com.</p>
				<p style="color:#999;font-size:12px;margin-top:24px">We're sorry to see you go. You can always create a new account in the future.</p>
			</div>`,
	}

	jsonBody, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("marshal email request: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, "https://api.resend.com/emails", bytes.NewReader(jsonBody))
	if err != nil {
		return fmt.Errorf("create email request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("send email: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("resend API error: status %d", resp.StatusCode)
	}

	return nil
}
