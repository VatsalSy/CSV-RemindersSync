// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import EventKit

@main
struct CSVRemindersSync {
    static func findRemindersList(named listName: String, in eventStore: EKEventStore) -> EKCalendar? {
        // Get all reminder lists (calendars)
        let calendars = eventStore.calendars(for: .reminder)
        
        // Try to find the specified list
        return calendars.first { calendar in
            calendar.title.lowercased() == listName.lowercased()
        }
    }
    
    static func findExistingReminder(with url: String, in eventStore: EKEventStore) -> EKReminder? {
        // Create a predicate to fetch all reminders
        let predicate = eventStore.predicateForReminders(in: nil)
        
        // Fetch reminders synchronously
        var existingReminders: [EKReminder]?
        let group = DispatchGroup()
        group.enter()
        
        eventStore.fetchReminders(matching: predicate) { reminders in
            existingReminders = reminders
            group.leave()
        }
        group.wait()
        
        // Search for a reminder with matching URL in notes
        return existingReminders?.first { reminder in
            if let notes = reminder.notes {
                return notes.contains("URL: \(url)")
            }
            return false
        }
    }
    
    static func main() async throws {
        // Get the CSV filename and list name from command line arguments
        guard CommandLine.arguments.count >= 2 else {
            print("Error: Please provide the CSV filename as an argument.")
            print("Usage: csv-reminders-sync <csv-file> [list-name]")
            return
        }
        
        let csvFilename = CommandLine.arguments[1]
        let listName = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil
        
        // 1. Locate the CSV file from the provided filename
        let csvURL = URL(fileURLWithPath: csvFilename)

        // 2. Read the file contents into a string.
        guard FileManager.default.fileExists(atPath: csvURL.path) else {
            print("Error: \(csvFilename) not found in the current directory.")
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
            print("No task data found in \(csvFilename).")
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

        // 6. Find the specified reminders list or use inbox
        let remindersCalendar: EKCalendar
        if let listName = listName, let specifiedList = findRemindersList(named: listName, in: eventStore) {
            remindersCalendar = specifiedList
            print("Using specified list: \(listName)")
        } else {
            if let defaultCalendar = eventStore.defaultCalendarForNewReminders() {
                remindersCalendar = defaultCalendar
                print("Using default Reminders list (Inbox)")
            } else {
                print("No Reminders list available.")
                return
            }
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

        // Keep track of processed URLs to avoid processing older entries of the same URL
        var processedUrls = Set<String>()
        
        // Process lines in reverse order (from bottom to top, excluding header)
        for line in lines.dropFirst().reversed() {
            let columns = parseCSVLine(String(line))
            
            // Get the URL first to check for existing reminder
            guard urlIndex >= 0, urlIndex < columns.count else {
                print("Error: URL column not found or invalid")
                continue
            }
            
            let url = columns[urlIndex].replacingOccurrences(of: "\"", with: "")
            
            // Skip if we've already processed this URL (means we've seen a more recent entry)
            if processedUrls.contains(url) {
                print("Skipping older entry for URL: \(url)")
                continue
            }
            
            // Mark this URL as processed
            processedUrls.insert(url)
            
            // Try to find an existing reminder with this URL
            let reminder: EKReminder
            if let existingReminder = findExistingReminder(with: url, in: eventStore) {
                reminder = existingReminder
                print("Found existing reminder with URL: \(url)")
            } else {
                reminder = EKReminder(eventStore: eventStore)
                reminder.calendar = remindersCalendar
                print("Creating new reminder for URL: \(url)")
            }

            // Update reminder fields
            if taskIndex >= 0, taskIndex < columns.count {
                reminder.title = columns[taskIndex].replacingOccurrences(of: "\"", with: "")
            }

            var notes = ""
            if statusIndex >= 0, statusIndex < columns.count {
                notes += "Status: \(columns[statusIndex].replacingOccurrences(of: "\"", with: ""))\n"
            }
            notes += "URL: \(url)"
            reminder.notes = notes

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

            // Save the reminder
            do {
                try eventStore.save(reminder, commit: true)
                print("Successfully \(reminder == reminder ? "updated" : "created") reminder: \(reminder.title ?? "Untitled")")
            } catch {
                print("Could not save reminder: \(error)")
            }
        }
        
        print("\nProcessing complete. Processed \(processedUrls.count) unique URLs.")
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
