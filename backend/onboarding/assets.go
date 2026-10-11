// Package webassets embeds the HTML templates and static files (CSS, images)
// so the server ships as a single binary.
package webassets

import "embed"

//go:embed templates static
var FS embed.FS
