#!/usr/bin/env bash
set -euo pipefail

OBOT_BIN="${OBOT_BIN:-obot}"
PROJECT_DIR="${PROJECT_DIR:-/tmp/obot-gpa-demo-$(date +%s)}"

print_cmd() {
  printf "\n$ %s\n" "$1"
}

run() {
  local cmd="$1"
  print_cmd "$cmd"
  eval "$cmd"
}

if [ -x "$OBOT_BIN" ]; then
  :
elif command -v "$OBOT_BIN" >/dev/null 2>&1; then
  :
else
  echo "obot not found. Set OBOT_BIN to your obot binary path."
  exit 1
fi

run "\"$OBOT_BIN\" version"

echo ""
echo "Project directory: $PROJECT_DIR"
echo ""

print_cmd "\"$OBOT_BIN\" fs write \"$PROJECT_DIR/README.md\" <<'EOF'"
"$OBOT_BIN" fs write "$PROJECT_DIR/README.md" <<'EOF'
# GPA Calculator

A tiny GPA calculator with a CLI and tests.

## Usage

```bash
python3 -m gpa_calculator.cli --course A:3 --course B+:4 --course C:2
```

## Tests

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v
```
EOF

print_cmd "\"$OBOT_BIN\" fs write \"$PROJECT_DIR/gpa_calculator/__init__.py\" <<'EOF'"
"$OBOT_BIN" fs write "$PROJECT_DIR/gpa_calculator/__init__.py" <<'EOF'
from .calculator import Course, calculate_gpa, parse_course, normalize_grade, normalize_credits

__all__ = ["Course", "calculate_gpa", "parse_course", "normalize_grade", "normalize_credits"]
EOF

print_cmd "\"$OBOT_BIN\" fs write \"$PROJECT_DIR/gpa_calculator/calculator.py\" <<'EOF'"
"$OBOT_BIN" fs write "$PROJECT_DIR/gpa_calculator/calculator.py" <<'EOF'
from dataclasses import dataclass
from typing import Iterable, Tuple, Dict, Any

GRADE_POINTS = {
    "A+": 4.0,
    "A": 4.0,
    "A-": 3.7,
    "B+": 3.3,
    "B": 3.0,
    "B-": 2.7,
    "C+": 2.3,
    "C": 2.0,
    "C-": 1.7,
    "D+": 1.3,
    "D": 1.0,
    "D-": 0.7,
    "F": 0.0,
}


@dataclass(frozen=True)
class Course:
    grade: float
    credits: float


def normalize_grade(value: Any) -> float:
    if isinstance(value, (int, float)):
        grade = float(value)
    else:
        grade_str = str(value).strip().upper()
        if grade_str in GRADE_POINTS:
            return GRADE_POINTS[grade_str]
        try:
            grade = float(grade_str)
        except ValueError as exc:
            raise ValueError(f"Invalid grade: {value}") from exc

    if grade < 0.0 or grade > 4.0:
        raise ValueError(f"Grade out of range: {grade}")
    return grade


def normalize_credits(value: Any) -> float:
    try:
        credits = float(value)
    except ValueError as exc:
        raise ValueError(f"Invalid credits: {value}") from exc

    if credits <= 0:
        raise ValueError(f"Credits must be positive: {credits}")
    return credits


def parse_course(grade: Any, credits: Any) -> Course:
    return Course(grade=normalize_grade(grade), credits=normalize_credits(credits))


def normalize_courses(courses: Iterable[Any]) -> Iterable[Course]:
    for item in courses:
        if isinstance(item, Course):
            yield item
        elif isinstance(item, (list, tuple)) and len(item) == 2:
            yield parse_course(item[0], item[1])
        elif isinstance(item, Dict):
            if "grade" not in item or "credits" not in item:
                raise ValueError("Course dict must have grade and credits.")
            yield parse_course(item["grade"], item["credits"])
        else:
            raise ValueError(f"Unsupported course format: {item}")


def calculate_gpa(courses: Iterable[Any], precision: int = 2) -> float:
    total_points = 0.0
    total_credits = 0.0

    for course in normalize_courses(courses):
        total_points += course.grade * course.credits
        total_credits += course.credits

    if total_credits <= 0:
        raise ValueError("Total credits must be greater than zero.")

    gpa = total_points / total_credits
    return round(gpa, precision)
EOF

print_cmd "\"$OBOT_BIN\" fs write \"$PROJECT_DIR/gpa_calculator/cli.py\" <<'EOF'"
"$OBOT_BIN" fs write "$PROJECT_DIR/gpa_calculator/cli.py" <<'EOF'
import argparse

from gpa_calculator.calculator import calculate_gpa, parse_course


def parse_course_arg(value: str):
    if ":" not in value:
        raise argparse.ArgumentTypeError("Course must be in GRADE:CREDITS format.")
    grade, credits = value.split(":", 1)
    return parse_course(grade, credits)


def main():
    parser = argparse.ArgumentParser(description="GPA Calculator")
    parser.add_argument(
        "--course",
        "-c",
        action="append",
        type=parse_course_arg,
        required=True,
        help="Course in GRADE:CREDITS format (e.g. A:3, 3.7:4).",
    )
    parser.add_argument("--precision", type=int, default=2, help="Decimal precision.")
    args = parser.parse_args()

    gpa = calculate_gpa(args.course, precision=args.precision)
    print(f"GPA: {gpa:.{args.precision}f}")


if __name__ == "__main__":
    main()
EOF

print_cmd "\"$OBOT_BIN\" fs write \"$PROJECT_DIR/tests/test_calculator.py\" <<'EOF'"
"$OBOT_BIN" fs write "$PROJECT_DIR/tests/test_calculator.py" <<'EOF'
import unittest

from gpa_calculator.calculator import calculate_gpa, parse_course


class TestCalculator(unittest.TestCase):
    def test_letter_grades(self):
        courses = [parse_course("A", 3), parse_course("B", 3)]
        self.assertEqual(calculate_gpa(courses), 3.5)

    def test_numeric_grades(self):
        courses = [parse_course(3.7, 4), parse_course(3.3, 3)]
        self.assertEqual(calculate_gpa(courses), 3.53)

    def test_mixed_tuple_input(self):
        courses = [("A-", 4), ("B+", 3)]
        self.assertEqual(calculate_gpa(courses), 3.53)

    def test_invalid_grade(self):
        with self.assertRaises(ValueError):
            parse_course("Z", 3)

    def test_invalid_credits(self):
        with self.assertRaises(ValueError):
            parse_course("A", 0)


if __name__ == "__main__":
    unittest.main()
EOF

run "cd \"$PROJECT_DIR\""
run "PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p \"test_*.py\" -v"
run "PYTHONDONTWRITEBYTECODE=1 python3 -m gpa_calculator.cli --course A:3 --course B+:4 --course C:2"

echo ""
echo "✅ GPA calculator project created and tested in $PROJECT_DIR"
