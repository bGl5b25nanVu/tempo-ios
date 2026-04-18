import SwiftUI

struct CalendarView: View {
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month header
                HStack {
                    Button(action: {}) { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                        .font(.title2.bold())
                    Spacer()
                    Button(action: {}) { Image(systemName: "chevron.right") }
                }
                .padding()

                // Day of week headers
                HStack {
                    ForEach(["Sun","Mon","Tue","Wed","Thu","Fri","Sat"], id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Calendar grid (placeholder)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(1...35, id: \.self) { day in
                        Text("\(day)")
                            .font(.body)
                            .frame(width: 40, height: 40)
                            .background(day == 18 ? Color.blue.opacity(0.2) : Color.clear)
                            .clipShape(Circle())
                    }
                }
                .padding()

                Spacer()
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CalendarView()
}
