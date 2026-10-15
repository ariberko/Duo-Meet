import SwiftUI

/// The bottom input used to add notes, decisions and tasks.
/// Return adds the item and keeps the keyboard up for the next one.
struct CaptureBar: View {
    @Bindable var draft: LiveDraft
    /// Which kinds this bar offers. One kind hides the picker.
    let kinds: [CaptureKind]
    /// Bound to the shared draft kind when several kinds are offered.
    @Binding var kind: CaptureKind
    let ownerSuggestions: [String]
    let onSubmit: (CaptureKind) -> Void

    @FocusState private var isFocused: Bool
    @State private var showOwnerPrompt = false
    @State private var typedOwner = ""
    @State private var showDatePicker = false

    private var current: CaptureKind {
        kinds.contains(kind) ? kind : (kinds.first ?? .note)
    }

    private var text: Binding<String> {
        current == .task ? $draft.taskTitle : $draft.noteText
    }

    private var canSubmit: Bool {
        !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if kinds.count > 1 {
                Picker("Add as", selection: Binding(get: { current }, set: { kind = $0 })) {
                    ForEach(kinds) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            if current == .task {
                taskOptions
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField(current.placeholder, text: text)
                    .focused($isFocused)
                    .submitLabel(.return)
                    .onSubmit(submit)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel(current.placeholder)

                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(!canSubmit)
                .accessibilityLabel("Add \(current.title.lowercased())")
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .alert("Owner", isPresented: $showOwnerPrompt) {
            TextField("Name", text: $typedOwner)
                .textContentType(.name)
            Button("Cancel", role: .cancel) {}
            Button("Set") { draft.taskOwner = typedOwner.trimmingCharacters(in: .whitespaces) }
        }
        .sheet(isPresented: $showDatePicker) {
            DueDateSheet(date: draft.taskDueDate ?? Date()) { draft.taskDueDate = $0 }
        }
    }

    private var taskOptions: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(ownerSuggestions, id: \.self) { name in
                    Button(name) { draft.taskOwner = name }
                }
                Button("Type a name…", systemImage: "keyboard") {
                    typedOwner = draft.taskOwner
                    showOwnerPrompt = true
                }
                if !draft.taskOwner.isEmpty {
                    Button("No owner", systemImage: "xmark", role: .destructive) { draft.taskOwner = "" }
                }
            } label: {
                Chip(title: draft.taskOwner.isEmpty ? "Owner" : draft.taskOwner,
                     systemImage: "person",
                     isActive: !draft.taskOwner.isEmpty)
            }
            .accessibilityLabel(draft.taskOwner.isEmpty ? "Choose owner" : "Owner: \(draft.taskOwner)")

            Menu {
                Button("Today") { draft.taskDueDate = Self.day(offset: 0) }
                Button("Tomorrow") { draft.taskDueDate = Self.day(offset: 1) }
                Button("In a week") { draft.taskDueDate = Self.day(offset: 7) }
                Button("Pick a date…", systemImage: "calendar") { showDatePicker = true }
                if draft.taskDueDate != nil {
                    Button("No due date", systemImage: "xmark", role: .destructive) { draft.taskDueDate = nil }
                }
            } label: {
                Chip(title: draft.taskDueDate?.formatted(date: .abbreviated, time: .omitted) ?? "Due",
                     systemImage: "calendar",
                     isActive: draft.taskDueDate != nil)
            }
            .accessibilityLabel(draft.taskDueDate == nil ? "Choose due date" : "Due date set")

            Spacer(minLength: 0)
        }
    }

    private func submit() {
        guard canSubmit else { return }
        onSubmit(current)
        isFocused = true
    }

    private static func day(offset: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }
}

struct Chip: View {
    let title: String
    let systemImage: String
    var isActive = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            .background(
                Capsule().fill(isActive ? Color.accentColor.opacity(0.14) : Color(.tertiarySystemFill))
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

private struct DueDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var date: Date
    let onPick: (Date) -> Void

    var body: some View {
        NavigationStack {
            DatePicker("Due date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Due Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Set") {
                            onPick(Calendar.current.startOfDay(for: date))
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}
