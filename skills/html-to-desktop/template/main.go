package main

import (
	"embed"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
)

// web/ 폴더(HTML/CSS/JS)를 exe 안에 넣는다. npm 빌드 단계는 없다.
//
//go:embed all:web
var assets embed.FS

func main() {
	app := NewApp("{{SLUG}}")

	err := wails.Run(&options.App{
		Title:     "{{TITLE}}",
		Width:     {{WIDTH}},
		Height:    {{HEIGHT}},
		MinWidth:  400,
		MinHeight: 300,
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		OnStartup: app.startup,
		// Bind 에 넣은 구조체의 공개 메서드를 HTML 에서 window.go.main.App.<메서드>() 로 부른다.
		Bind: []interface{}{
			app,
		},
	})
	if err != nil {
		println("Error:", err.Error())
	}
}
