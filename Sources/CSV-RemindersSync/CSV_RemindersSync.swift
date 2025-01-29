// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import EventKit

@main
struct CSVRemindersSync {
    static func main() async throws {
        // 1. Locate the CSV file named "test.csv" in the current folder.
        let csvURL = URL(fileURLWithPath: "test.csv")

        // 2. Read the file contents into a string.
        guard FileManager.default.fileExists(atPath: csvURL.path) else {
            print("Error: test.csv not found in the current directory.")
            return
        }
        let csvContent = try String(contentsOf: csvURL, encoding: .utf8)

        // 3. Split the CSV data into lines, ignoring empty lines.
        let lines = csvContent
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 4. Make sure there's at least a header row plus one data row.
        guard lines.count > 1 else {
            print("No task data found in test.csv.")
            return
        }

        // 5. Request authorization to access Reminders.
        let eventStore = EKEventStore()
        do {
            try await eventStore.requestAccess(to: .reminder)
        } catch {
            print("Unable to request access for Reminders: \(error)")
            return
        }

        // 6. Use the default Reminders calendar for new reminders.
        guard let remindersCalendar = eventStore.defaultCalendarForNewReminders() else {
            print("No default Reminders calendar available.")
            return
        }

        // 7. Split each row by comma and create a reminder.
        //    Expected CSV columns: url,task,status,priority,duedate
        let headerColumns = parseCSVLine(String(lines[0])).map { $0.lowercased() }
        let urlIndex = headerColumns.firstIndex(of: "\"url\"") ?? headerColumns.firstIndex(of: "url") ?? -1
        let taskIndex = headerColumns.firstIndex(of: "\"task\"") ?? headerColumns.firstIndex(of: "task") ?? -1
        let statusIndex = headerColumns.firstIndex(of: "\"status\"") ?? headerColumns.firstIndex(of: "status") ?? -1
        let priorityIndex = headerColumns.firstIndex(of: "\"priority\"") ?? headerColumns.firstIndex(of: "priority") ?? -1
        let dueDateIndex = headerColumns.firstIndex(of: "\"duedate\"") ?? headerColumns.firstIndex(of: "duedate") ?? -1

        print("Found columns - URL: \(urlIndex), Task: \(taskIndex), Status: \(statusIndex), Priority: \(priorityIndex), Due Date: \(dueDateIndex)")

        for line in lines.dropFirst() {
            let columns = parseCSVLine(String(line))
            
            // Create a new reminder.
            let reminder = EKReminder(eventStore: eventStore)
            reminder.calendar = remindersCalendar

            // Assign values from CSV if available.
            if taskIndex >= 0, taskIndex < columns.count {
                reminder.title = columns[taskIndex].replacingOccurrences(of: "\"", with: "")
            }

            if statusIndex >= 0, statusIndex < columns.count {
                reminder.notes = "Status: \(columns[statusIndex].replacingOccurrences(of: "\"", with: ""))"
            }

            if priorityIndex >= 0, priorityIndex < columns.count {
                let priorityStr = columns[priorityIndex].replacingOccurrences(of: "\"", with: "")
                if let priority = Int(priorityStr) {
                    reminder.priority = priority
                }
            }

            if dueDateIndex >= 0, dueDateIndex < columns.count {
                let dateStr = columns[dueDateIndex].replacingOccurrences(of: "\"", with: "")
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "M/dd/yyyy"
                if let dueDate = dateFormatter.date(from: dateStr) {
                    reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
                }
            }

            // Store the URL in the notes
            if urlIndex >= 0, urlIndex < columns.count {
                let url = columns[urlIndex].replacingOccurrences(of: "\"", with: "")
                if let existingNotes = reminder.notes {
                    reminder.notes = "\(existingNotes)\nURL: \(url)"
                } else {
                    reminder.notes = "URL: \(url)"
                }
            }

            // 8. Save the reminder to Apple Reminders.
            do {
                try eventStore.save(reminder, commit: true)
                print("Successfully created reminder: \(reminder.title ?? "Untitled")")
            } catch {
                print("Could not save reminder: \(error)")
            }
        }
    }
    
    // Helper function to parse CSV lines properly
    static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        result.append(currentField)
        return result
    }
}
