package main

import "testing"

func TestSaveLoadText(t *testing.T) {
	a := &App{dataDir: t.TempDir()}
	if err := a.SaveText("메모.txt", "안녕하세요"); err != nil {
		t.Fatal(err)
	}
	got, err := a.LoadText("메모.txt")
	if err != nil || got != "안녕하세요" {
		t.Fatalf("got %q, %v", got, err)
	}
	if got, err := a.LoadText("없음.txt"); err != nil || got != "" {
		t.Fatalf("missing file: got %q, %v", got, err)
	}
}

func TestRejectsPaths(t *testing.T) {
	a := &App{dataDir: t.TempDir()}
	for _, n := range []string{"", ".", "..", "../x.txt", `..\x.txt`, "a/b.txt", `a\b.txt`, `C:\x.txt`, ".hidden"} {
		if err := a.SaveText(n, "x"); err == nil {
			t.Errorf("SaveText(%q) 가 허용됨", n)
		}
	}
}
