package cli

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/spf13/cobra"
)

var (
	fsMode   string
	fsAppend bool
	fsForce  bool
)

// fsCmd groups filesystem helpers used by scripted workflows
var fsCmd = &cobra.Command{
	Use:   "fs",
	Short: "Filesystem helpers for scripted workflows",
}

var fsWriteCmd = &cobra.Command{
	Use:   "write <path>",
	Short: "Write file content from stdin",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		path := args[0]
		content, err := readStdin()
		if err != nil {
			return err
		}

		mode, err := resolveMode(path, fsMode)
		if err != nil {
			return err
		}

		if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
			return err
		}

		if fsAppend {
			file, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, mode)
			if err != nil {
				return err
			}
			defer file.Close()
			if _, err := file.Write(content); err != nil {
				return err
			}
			return nil
		}

		return os.WriteFile(path, content, mode)
	},
}

var fsDeleteCmd = &cobra.Command{
	Use:   "delete <path>",
	Short: "Delete a file or directory",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		path := args[0]
		info, err := os.Stat(path)
		if err != nil {
			if os.IsNotExist(err) && fsForce {
				return nil
			}
			return err
		}

		if info.IsDir() {
			if !fsForce {
				return fmt.Errorf("refusing to delete directory without --force: %s", path)
			}
			return os.RemoveAll(path)
		}

		return os.Remove(path)
	},
}

func init() {
	fsWriteCmd.Flags().StringVar(&fsMode, "mode", "", "File mode (octal, e.g. 0644)")
	fsWriteCmd.Flags().BoolVar(&fsAppend, "append", false, "Append to file instead of overwriting")

	fsDeleteCmd.Flags().BoolVar(&fsForce, "force", false, "Delete directories recursively or ignore missing files")

	fsCmd.AddCommand(fsWriteCmd)
	fsCmd.AddCommand(fsDeleteCmd)
}

func readStdin() ([]byte, error) {
	info, err := os.Stdin.Stat()
	if err != nil {
		return nil, err
	}
	if (info.Mode() & os.ModeCharDevice) != 0 {
		return nil, errors.New("stdin required: pass file content via heredoc or pipe")
	}
	return io.ReadAll(os.Stdin)
}

func resolveMode(path string, modeFlag string) (os.FileMode, error) {
	if modeFlag != "" {
		parsed, err := strconv.ParseUint(strings.TrimSpace(modeFlag), 8, 32)
		if err != nil {
			return 0, fmt.Errorf("invalid mode: %s", modeFlag)
		}
		return os.FileMode(parsed), nil
	}

	info, err := os.Stat(path)
	if err == nil {
		return info.Mode().Perm(), nil
	}

	return 0644, nil
}
