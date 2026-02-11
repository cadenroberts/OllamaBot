package context

// Budget represents a token budget allocation across context categories.
type Budget struct {
	Total     int
	Task      int
	Files     int
	Project   int
	History   int
	Memory    int
	Errors    int
	Reserve   int

	// Tracking
	UsedTask    int
	UsedFiles   int
	UsedProject int
	UsedHistory int
	UsedMemory  int
	UsedErrors  int
}

// NewBudget creates a token budget from allocation percentages and a total.
func NewBudget(total int, alloc map[string]float64) *Budget {
	b := &Budget{Total: total}
	b.Task = int(float64(total) * getOrDefault(alloc, "task", 0.20))
	b.Files = int(float64(total) * getOrDefault(alloc, "files", 0.35))
	b.Project = int(float64(total) * getOrDefault(alloc, "project", 0.15))
	b.History = int(float64(total) * getOrDefault(alloc, "history", 0.12))
	b.Memory = int(float64(total) * getOrDefault(alloc, "memory", 0.12))
	b.Errors = int(float64(total) * getOrDefault(alloc, "errors", 0.06))
	b.Reserve = total - b.Task - b.Files - b.Project - b.History - b.Memory - b.Errors
	if b.Reserve < 0 {
		b.Reserve = 0
	}
	return b
}

// RemainingTask returns tokens remaining in the task budget.
func (b *Budget) RemainingTask() int    { return b.Task - b.UsedTask }

// RemainingFiles returns tokens remaining in the files budget.
func (b *Budget) RemainingFiles() int   { return b.Files - b.UsedFiles }

// RemainingHistory returns tokens remaining in the history budget.
func (b *Budget) RemainingHistory() int { return b.History - b.UsedHistory }

// TotalUsed returns total tokens consumed.
func (b *Budget) TotalUsed() int {
	return b.UsedTask + b.UsedFiles + b.UsedProject + b.UsedHistory + b.UsedMemory + b.UsedErrors
}

// TotalRemaining returns total tokens remaining.
func (b *Budget) TotalRemaining() int { return b.Total - b.TotalUsed() }

func getOrDefault(m map[string]float64, key string, def float64) float64 {
	if v, ok := m[key]; ok {
		return v
	}
	return def
}
