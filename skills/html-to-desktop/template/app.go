package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"regexp"
)

// App 의 공개(대문자로 시작하는) 메서드는 HTML 에서 Promise 로 부를 수 있다:
//
//	const text = await window.go.main.App.LoadText("memo.txt");
//	await window.go.main.App.SaveText("memo.txt", "내용");
//
// 메서드를 추가하려면 아래처럼 func (a *App) 이름(인자) (결과, error) 를 쓰고 다시 빌드한다.
// error 를 반환하면 JS 쪽 Promise 가 reject 된다.
type App struct {
	ctx     context.Context
	dataDir string
}

func NewApp(appID string) *App {
	base, err := os.UserConfigDir() // Windows: %APPDATA%
	if err != nil {
		base = "."
	}
	return &App{dataDir: filepath.Join(base, appID)}
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// 파일 이름만 허용한다. 경로(.., \, /, 드라이브)를 막아 HTML 쪽 스크립트가 데이터 폴더 밖을 읽고 쓰지 못하게 한다.
var safeName = regexp.MustCompile(`^[\p{L}\p{N}_\-][\p{L}\p{N}_\-. ]{0,99}$`)

func (a *App) path(name string) (string, error) {
	if !safeName.MatchString(name) || name == "." || name == ".." {
		return "", errors.New("허용되지 않는 파일 이름: " + name)
	}
	return filepath.Join(a.dataDir, name), nil
}

// DataDir 는 SaveText/LoadText 가 쓰는 폴더 경로를 돌려준다.
func (a *App) DataDir() string {
	return a.dataDir
}

// SaveText 는 데이터 폴더의 name 파일에 content 를 UTF-8 로 쓴다.
func (a *App) SaveText(name, content string) error {
	p, err := a.path(name)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(a.dataDir, 0o755); err != nil {
		return err
	}
	return os.WriteFile(p, []byte(content), 0o644)
}

// LoadText 는 데이터 폴더의 name 파일을 읽는다. 파일이 없으면 빈 문자열을 돌려준다.
func (a *App) LoadText(name string) (string, error) {
	p, err := a.path(name)
	if err != nil {
		return "", err
	}
	b, err := os.ReadFile(p)
	if errors.Is(err, os.ErrNotExist) {
		return "", nil
	}
	return string(b), err
}
