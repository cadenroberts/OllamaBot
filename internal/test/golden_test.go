package test

import (
	"os"
	"testing"
)

func TestAssertGolden(t *testing.T) {
	// Use a temporary test name to avoid polluting real testdata
	testName := "test_assert_golden"
	actual := []byte("hello world")

	// 1. Test creation (UPDATE_GOLDEN=true)
	os.Setenv("UPDATE_GOLDEN", "true")
	AssertGolden(t, testName, actual)

	// 2. Test comparison (UPDATE_GOLDEN=false)
	os.Setenv("UPDATE_GOLDEN", "false")
	AssertGolden(t, testName, actual)

	// 3. Cleanup
	os.Remove("testdata/" + testName + ".golden")
}

func TestAssertGoldenJSON(t *testing.T) {
	testName := "test_assert_golden_json"
	data := map[string]interface{}{
		"key":   "value",
		"count": 42,
	}

	// 1. Test creation
	os.Setenv("UPDATE_GOLDEN", "true")
	AssertGoldenJSON(t, testName, data)

	// 2. Test comparison
	os.Setenv("UPDATE_GOLDEN", "false")
	AssertGoldenJSON(t, testName, data)

	// 3. Cleanup
	os.Remove("testdata/" + testName + ".json.golden")
}

func TestSnapshot(t *testing.T) {
	testName := "test_snapshot"
	snapshot := Snapshot{
		ID:     "test-1",
		Prompt: "hello",
		Output: "hi there",
		Model:  "llama3",
	}

	// 1. Save
	os.Setenv("UPDATE_GOLDEN", "true")
	SaveSnapshot(t, testName, snapshot)

	// 2. Load and verify
	loaded := LoadSnapshot(t, testName)
	if loaded.ID != snapshot.ID || loaded.Prompt != snapshot.Prompt {
		t.Errorf("loaded snapshot mismatch: %+v", loaded)
	}

	// 3. Cleanup
	os.Remove("testdata/snapshots/" + testName + ".json.golden")
	os.RemoveAll("testdata/snapshots")
}
