# CSV-RemindersSync

A Swift command-line tool to synchronize tasks from a CSV file with Apple Reminders.

## Features

- Imports tasks from CSV file to Apple Reminders


## Requirements

- macOS 13.0 or later
- Swift 6.0 or later

## Installation

1. Clone the repository
2. Build the package:
   ```bash
   swift build -c release
   ```
3. The binary will be located at `.build/release/csv-reminders-sync`

## Usage

```bash
csv-reminders-sync <csv-file-path> <reminders-list-name>
```

### Arguments

- `csv-file-path`: Path to the CSV file containing tasks
- `reminders-list-name`: Name of the Reminders list to sync with

### CSV Format

The CSV file should have the following columns:
```
url,task,status,priority,duedate
```

Example:
```csv
"url","task","status","priority","duedate"
"https://example.com","Example task","In progress","3","1/30/2025"
```

## License

MIT
