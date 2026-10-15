import SwiftUI
import MeetingCore

/// One task row: a check button plus the task text. Tapping the text opens the editor.
struct ActionItemRow: View {
    let item: ActionItem
    var onToggle: () -> Void
    var onEdit: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? Color.secondary : Color.accentColor)
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.isCompleted ? "Mark \(item.title) as not done" : "Mark \(item.title) as done")

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ActionItemMeta(item: item)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit task")
        }
        .padding(.vertical, 2)
    }
}

struct ActionItemMeta: View {
    let item: ActionItem

    var body: some View {
        if item.owner != nil || item.dueDate != nil {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { content }
                VStack(alignment: .leading, spacing: 2) { content }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let owner = item.owner {
            Label(owner, systemImage: "person")
        }
        if let due = item.dueDate {
            let overdue = item.isOverdue()
            Label {
                Text(overdue ? "Overdue · \(due.formatted(date: .abbreviated, time: .omitted))"
                             : due.formatted(date: .abbreviated, time: .omitted))
            } icon: {
                Image(systemName: "calendar")
            }
            .foregroundStyle(overdue ? Color.red : Color.secondary)
        }
    }
}

/// Full editor for one task.
struct ActionItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: ActionItem
    @State private var hasDueDate: Bool
    @State private var confirmDelete = false
    let ownerSuggestions: [String]
    let onSave: (ActionItem) -> Void
    let onDelete: () -> Void

    init(item: ActionItem, ownerSuggestions: [String], onSave: @escaping (ActionItem) -> Void, onDelete: @escaping () -> Void) {
        _item = State(initialValue: item)
        _hasDueDate = State(initialValue: item.dueDate != nil)
        self.ownerSuggestions = ownerSuggestions
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var canSave: Bool {
        !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var owner: Binding<String> {
        Binding(get: { item.owner ?? "" }, set: { item.owner = $0 })
    }

    private var dueDate: Binding<Date> {
        Binding(get: { item.dueDate ?? Date() }, set: { item.dueDate = $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs to happen?", text: $item.title, axis: .vertical)
                        .lineLimit(1...6)
                }
                Section {
                    TextField("Owner (optional)", text: owner)
                        .textContentType(.name)
                    if !ownerSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(ownerSuggestions, id: \.self) { name in
                                    Button(name) { item.owner = name }
                                        .buttonStyle(.bordered)
                                        .tint(item.owner == name ? Color.accentColor : Color.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Owner")
                }
                Section("Due date") {
                    Toggle("Set a due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due", selection: dueDate, displayedComponents: .date)
                    }
                }
                Section {
                    Toggle("Done", isOn: $item.isCompleted)
                }
                Section {
                    Button("Delete Task", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var result = item
                        if !hasDueDate { result.dueDate = nil } else if result.dueDate == nil { result.dueDate = Date() }
                        onSave(result)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .confirmationDialog("Delete this task?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Task", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            }
        }
    }
}
