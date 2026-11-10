// Copy into the pinned Mixtape source checkout and run with IRONMON_STORE_ZIP
// and IRONMON_STORE_CATALOG set. Uses Mixtape's own installer and fake SD card.
package main

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestMiyooIronMONStore(t *testing.T) {
	read := func(name string) []byte {
		b, err := os.ReadFile(name)
		if err != nil {
			t.Fatal(err)
		}
		return b
	}
	zipPath := os.Getenv("IRONMON_STORE_ZIP")
	if zipPath == "" {
		t.Skip("Provide a built IronMON store package")
	}
	archive := read(zipPath)
	ports, _, err := parseSource(read(os.Getenv("IRONMON_STORE_CATALOG")), nil)
	if err != nil || len(ports) != 1 {
		t.Fatalf("Invalid catalog: %v", err)
	}
	p := ports[0]
	if !p.Direct() || !p.IsApp() || p.Assets != "owned" || p.SHA256 == "" {
		t.Fatal("Expected a direct, hashed BYO app")
	}
	fx := newFixture(t)
	name := filepath.Base(zipPath)
	fx.files["/"+name] = archive
	p.URL = fx.srv.URL + "/" + name
	install := func() error {
		plan, err := fx.env.PlanFor(p, false)
		if err != nil {
			return err
		}
		_, err = fx.env.Install(context.Background(), p, plan, func(Progress) {})
		return err
	}
	write := func(rel, content string) {
		abs := filepath.Join(fx.env.SDRoot, rel)
		if err := os.MkdirAll(filepath.Dir(abs), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(abs, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	check := func(files map[string]string) {
		for rel, value := range files {
			if fx.read(rel) != value {
				t.Fatalf("Changed user data: %s", rel)
			}
		}
	}
	const app = "App/IronMON-Mixtape/"
	user := map[string]string{"App/IronMON/data/current.state": "original app state", "App/IronMON/settings.ini": "original app settings"}
	for path, value := range user {
		write(path, value)
	}
	good := p.SHA256
	p.SHA256 = strings.Repeat("0", 64)
	if err := install(); err == nil || fx.exists(app+"config.json") {
		t.Fatal("Bad download was not rejected before installation")
	}
	p.SHA256 = good
	if err := install(); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(fx.read(app+"config.json"), "mixtape-launch.sh") || !fx.exists(app+"store/ironmon-setup-lua") {
		t.Fatal("Wrong app layout")
	}
	if fx.exists(app+"source.gba") || fx.exists(app+"settings.ini") || fx.exists(app+"data") {
		t.Fatal("Archive contains game or mutable data")
	}
	user[app+"source.gba"] = "private source ROM placeholder"
	user[app+"source-qol.gba"] = "prepared ROM placeholder"
	user[app+"settings.ini"] = "my settings"
	user[app+"data/current.state"] = "my run"
	user[app+"data/current.tdat"] = "my Tracker notes"
	for path, value := range user {
		write(path, value)
	}
	p.Version += "-test-update"
	if err := install(); err != nil {
		t.Fatal(err)
	}
	check(user)
	if _, _, err := fx.env.Uninstall(p); err != nil {
		t.Fatal(err)
	}
	if fx.exists(app + "config.json") {
		t.Fatal("Mixtape did not remove the packaged app")
	}
	check(user)
}
