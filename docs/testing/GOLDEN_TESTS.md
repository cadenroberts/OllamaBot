# Golden Testing in OllamaBot

OllamaBot uses "golden testing" (also known as snapshot testing) to ensure that the output of various components (especially those involving LLMs or complex data structures) remains consistent over time.

## Overview

Golden tests compare the actual output of a component against a "golden" file stored in the repository. If the output changes, the test fails, alerting the developer to a potential regression or an intentional change that needs to be reviewed and updated.

## Utilities

The golden test utilities are located in `internal/test/golden.go`:

- `AssertGolden(t, name, actual)`: Compares a byte slice against a `.golden` file.
- `AssertGoldenJSON(t, name, actual)`: Marshals an object to JSON and compares it against a `.json.golden` file.
- `SaveSnapshot(t, name, snapshot)`: Saves a prompt/output pair for LLM testing.
- `LoadSnapshot(t, name)`: Loads a previously saved snapshot.

## Workflow

### 1. Creating or Updating Golden Files

When you create a new test or intentionally change the output, run the tests with the `UPDATE_GOLDEN` environment variable set to `true`:

```bash
UPDATE_GOLDEN=true go test ./internal/...
```

This will create the golden files if they don't exist or overwrite them if they do.

### 2. Verifying Output

During normal CI or local development, run the tests as usual:

```bash
go test ./internal/...
```

If the output diverges from the golden file, the test will fail and show a diff.

## LLM Snapshots

For testing LLM interactions, we capture "snapshots" of the prompt and the expected output. These are stored in `internal/test/testdata/snapshots/`.

Example of a snapshot test:

```go
func TestModelOutput(t *testing.T) {
    prompt := "Translate 'hello' to French"
    output := "bonjour"
    
    snapshot := test.Snapshot{
        ID:     "translation-hello",
        Prompt: prompt,
        Output: output,
        Model:  "llama3",
    }
    
    test.SaveSnapshot(t, "translation_test", snapshot)
}
```

## Directory Structure

- `internal/test/testdata/*.golden`: Text-based golden files.
- `internal/test/testdata/*.json.golden`: JSON-based golden files.
- `internal/test/testdata/snapshots/*.json.golden`: LLM prompt/output snapshots.
