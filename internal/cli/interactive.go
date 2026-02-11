// Package cli implements the command-line interface for OllamaBot.
package cli

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/croberts/obot/internal/config"
	"github.com/croberts/obot/internal/ollama"
	"github.com/croberts/obot/internal/ui"
)

// interactiveCmd represents the interactive chat command
var interactiveCmd = &cobra.Command{
	Use:     "interactive",
	Aliases: []string{"i"},
	Short:   "Start an interactive chat session with OllamaBot",
	Long: `Starts a persistent chat session where you can interact with the 
agent directly. This mode maintains history and is distinct from the 
one-shot 'orchestrate' command.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		return startInteractiveMode()
	},
}

type chatSession struct {
	history []chatMessage
	model   string
	client  *ollama.Client
	files   map[string]string // Loaded file contents
}

type chatMessage struct {
	Role    string    `json:"role"`
	Content string    `json:"content"`
	Time    time.Time `json:"time"`
}

func runInteractiveMode(path string, start, end int) error {
	reader := bufio.NewReader(os.Stdin)
	ctx := context.Background()

	// Load config
	cfg, err := config.Load()
	if err != nil {
		cfg = config.Default()
	}

	// Initialize Ollama client
	client := ollama.NewClient(ollama.WithBaseURL(cfg.OllamaURL))
	model := cfg.Unified.Models.Coder.Default
	if model == "" {
		model = "qwen2.5-coder:32b"
	}

	session := &chatSession{
		history: make([]chatMessage, 0),
		model:   model,
		client:  client,
		files:   make(map[string]string),
	}

	// Load initial file if provided
	if path != "" {
		content, err := os.ReadFile(path)
		if err == nil {
			session.files[path] = string(content)
		}
	}

	fmt.Print(ui.ClearScreen)
	fmt.Print(ui.CursorHome)
	
	header := []string{
		"Welcome to OllamaBot Chat",
		"Active Model: " + model,
		"File: " + path,
		"",
		"Type '/help' for commands, '/exit' to quit.",
	}
	fmt.Print(ui.BoxWithTitle("OllamaBot Interactive", header, 60))
	fmt.Println()

	for {
		fmt.Print(ui.TokyoBlueBold + "user> " + ui.ANSIReset)
		input, err := reader.ReadString('\n')
		if err != nil {
			return err
		}

		input = strings.TrimSpace(input)
		if input == "" {
			continue
		}

		// Handle slash commands
		if strings.HasPrefix(input, "/") {
			parts := strings.Split(input, " ")
			cmd := strings.ToLower(parts[0])
			
			switch cmd {
			case "/exit", "/quit":
				fmt.Println(ui.Yellow("Goodbye!"))
				return nil
			case "/help":
				showInteractiveHelp()
				continue
			case "/history":
				showHistory(session.history)
				continue
			case "/clear":
				session.history = make([]chatMessage, 0)
				fmt.Println(ui.Green("Chat history cleared."))
				continue
			case "/model":
				if len(parts) > 1 {
					session.model = parts[1]
					fmt.Printf(ui.Green("Switched to model: %s\n"), session.model)
				} else {
					fmt.Printf("Current model: %s\n", ui.TokyoBlueBold+session.model+ui.ANSIReset)
				}
				continue
			case "/file":
				if len(parts) > 1 {
					filePath := parts[1]
					content, err := os.ReadFile(filePath)
					if err != nil {
						fmt.Printf(ui.Red("Error reading file: %v\n"), err)
					} else {
						session.files[filePath] = string(content)
						fmt.Printf(ui.Green("Loaded file: %s (%d bytes)\n"), filePath, len(content))
					}
				} else {
					fmt.Println(ui.Yellow("Usage: /file <path>"))
				}
				continue
			case "/save":
				saveChat(session)
				continue
			}
		}

		// Add user message to history
		session.history = append(session.history, chatMessage{
			Role:    "user",
			Content: input,
			Time:    time.Now(),
		})

		// Build prompt with context
		prompt := buildPrompt(session)

		// Generate response
		fmt.Print(ui.ANSIGreen + "bot> " + ui.ANSIReset)
		
		// Set the model for this request
		session.client.SetModel(session.model)
		
		resp, _, err := session.client.Generate(ctx, prompt)
		if err != nil {
			fmt.Printf(ui.Red("\nError: %v\n"), err)
			continue
		}

		fmt.Println(resp)
		
		// Add bot message to history
		session.history = append(session.history, chatMessage{
			Role:    "assistant",
			Content: resp,
			Time:    time.Now(),
		})
		fmt.Println()
	}
}

func startInteractiveMode() error {
	return runInteractiveMode("", 0, 0)
}

func buildPrompt(s *chatSession) string {
	var sb strings.Builder
	
	// Add file context
	if len(s.files) > 0 {
		sb.WriteString("System: You have access to the following files:\n")
		for path, content := range s.files {
			sb.WriteString(fmt.Sprintf("\n--- File: %s ---\n%s\n--- End File ---\n", path, content))
		}
		sb.WriteString("\n")
	}

	// Add chat history
	for _, msg := range s.history {
		if msg.Role == "user" {
			sb.WriteString("User: " + msg.Content + "\n")
		} else {
			sb.WriteString("Assistant: " + msg.Content + "\n")
		}
	}
	
	sb.WriteString("Assistant: ")
	return sb.String()
}

func showInteractiveHelp() {
	help := []string{
		"/help          Show this help message",
		"/model <name>  Show or change the active model",
		"/file <path>   Load a file into chat context",
		"/history       Show current chat history",
		"/clear         Clear chat history",
		"/save          Save chat history to session.json",
		"/exit          Exit interactive mode",
	}
	fmt.Print(ui.BoxWithTitle("Available Commands", help, 60))
	fmt.Println()
}

func showHistory(history []chatMessage) {
	fmt.Println(ui.Separator(60))
	fmt.Println(ui.BoldBlue("Chat History:"))
	for _, msg := range history {
		role := ui.TokyoBlueBold + "user"
		if msg.Role == "assistant" {
			role = ui.ANSIGreen + "bot "
		}
		fmt.Printf("[%s] %s: %s\n", 
			msg.Time.Format("15:04:05"), 
			role+ui.ANSIReset, 
			msg.Content)
	}
	fmt.Println(ui.Separator(60))
	fmt.Println()
}

func saveChat(s *chatSession) {
	filename := fmt.Sprintf("chat_%s.json", time.Now().Format("20060102_150405"))
	data, _ := json.MarshalIndent(s.history, "", "  ")
	err := os.WriteFile(filename, data, 0644)
	if err != nil {
		fmt.Printf(ui.Red("Error saving chat: %v\n"), err)
	} else {
		fmt.Printf(ui.Green("Chat history saved to %s\n"), filename)
	}
}

func init() {
	// interactiveCmd is added in root.go
}
