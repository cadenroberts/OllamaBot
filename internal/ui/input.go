package ui

import (
	"bufio"
	"fmt"
	"io"
	"strings"
)

// InputHandler handles user input from the terminal.
type InputHandler struct {
	reader  *bufio.Reader
	writer  io.Writer
	history *CommandHistory
}

// NewInputHandler creates a new input handler.
func NewInputHandler(reader io.Reader, writer io.Writer) *InputHandler {
	return &InputHandler{
		reader:  bufio.NewReader(reader),
		writer:  writer,
		history: NewCommandHistory(),
	}
}

// ReadLine reads a single line of input.
func (ih *InputHandler) ReadLine() (string, error) {
	line, err := ih.reader.ReadString('\n')
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(line), nil
}

// Listen starts listening for input in a loop.
func (ih *InputHandler) Listen(onPrompt func(string), onCommand func(string)) {
	for {
		fmt.Fprint(ih.writer, "> ")
		line, err := ih.ReadLine()
		if err != nil {
			return
		}

		if strings.HasPrefix(line, "/") {
			ih.history.Add(line)
			onCommand(line)
		} else if line != "" {
			ih.history.Add(line)
			onPrompt(line)
		}
	}
}
