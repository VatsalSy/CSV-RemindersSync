# CSV-RemindersSync

A Swift command-line tool to synchronize tasks from a CSV file with Apple Reminders.

## Features

- Imports tasks from CSV file to Apple Reminders
- Updates existing reminders if they share the same URL
- For duplicate URLs in CSV, uses the most recent entry (last in file)
- Handles task properties:
  - Title
  - Status
  - Priority
  - Due date
  - URL (stored in notes)
- Supports custom Reminders lists (falls back to Inbox if not found)

## Requirements

- macOS 13.0 or later
- Swift 6.0 or later
- Access to Apple Reminders (will request permission on first run)

## Installation

1. Clone the repository
2. Build the package:
   ```bash
   swift build -c release
   ```
3. The binary will be located at `.build/release/csv-reminders-sync`

Alternatively, you can run directly using:
```bash
swift run csv-reminders-sync
```

## Usage

```bash
csv-reminders-sync <csv-file-path> [reminders-list-name]
```

### Arguments

- `csv-file-path`: (Required) Path to the CSV file containing tasks
- `reminders-list-name`: (Optional) Name of the Reminders list to sync with. If not specified or list not found, tasks will be added to the default Inbox.

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

#### Column Details:
- `url`: Unique identifier for the task (used for updating existing reminders)
- `task`: The title of the reminder
- `status`: Current status (stored in notes)
- `priority`: Priority level (number)
- `duedate`: Due date in M/dd/yyyy format

## Notes

- The URL is used as a unique identifier. If multiple entries have the same URL, only the last one in the file will be used
- When a list name is provided but not found, the tool will fall back to using the Inbox
- The tool will request permission to access Reminders on first run

## License

MIT
