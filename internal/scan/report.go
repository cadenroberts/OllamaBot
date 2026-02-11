package scan

import (
	"os"
	"text/template"
)

const htmlTemplate = `
<!DOCTYPE html>
<html>
<head>
    <title>OllamaBot Health Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #333; max-width: 1000px; margin: 0 auto; padding: 20px; background-color: #f5f7f9; }
        h1 { color: #1a1b26; border-bottom: 2px solid #7aa2f7; padding-bottom: 10px; }
        .summary { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 30px; display: flex; justify-content: space-around; align-items: center; }
        .score { font-size: 48px; font-weight: bold; color: #73c0ff; }
        .stats { font-size: 18px; }
        .issue { background: white; padding: 15px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); margin-bottom: 15px; border-left: 5px solid #ccc; }
        .issue.high { border-left-color: #f7768e; }
        .issue.medium { border-left-color: #e0af68; }
        .issue.low { border-left-color: #7aa2f7; }
        .issue-header { display: flex; justify-content: space-between; margin-bottom: 5px; }
        .severity { font-weight: bold; text-transform: uppercase; font-size: 12px; }
        .path { color: #565f89; font-family: monospace; }
        .message { font-size: 16px; }
    </style>
</head>
<body>
    <h1>🤖 OllamaBot Health Report</h1>
    
    <div class="summary">
        <div class="score">{{.Score}}/100</div>
        <div class="stats">
            <div><strong>Files Scanned:</strong> {{.FilesScanned}}</div>
            <div><strong>Total Issues:</strong> {{len .Issues}}</div>
        </div>
    </div>

    <h2>Issues</h2>
    {{range .Issues}}
    <div class="issue {{.Severity}}">
        <div class="issue-header">
            <span class="severity">{{.Severity}}</span>
            <span class="path">{{.Path}}:{{.Line}}</span>
        </div>
        <div class="message">{{.Message}}</div>
    </div>
    {{else}}
    <p>No issues found! Your project is healthy.</p>
    {{end}}
</body>
</html>
`

// GenerateHTMLReport generates an HTML health report.
func GenerateHTMLReport(report *HealthReport, outputPath string) error {
	tmpl, err := template.New("report").Parse(htmlTemplate)
	if err != nil {
		return err
	}

	f, err := os.Create(outputPath)
	if err != nil {
		return err
	}
	defer f.Close()

	return tmpl.Execute(f, report)
}
