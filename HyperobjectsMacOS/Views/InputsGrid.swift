//
//  InputsGrid.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 17/09/2025.
//

import SwiftUI

final class InputsGridModel: ObservableObject {
    @Published private(set) var grouped: [String: [SceneInput]] = [:]
    private var lastSignature: Int = 0
    
    func update(inputs: [SceneInput], groups: inout [SceneInputGroup]) {
        let sig = inputs.reduce(into: 0) { acc, i in
            acc = acc &* 16777619 ^ i.id.hashValue ^ (i.inputGroupName?.hashValue ?? 0)
        }
        guard sig != lastSignature else { return }
        lastSignature = sig
        
        // Rebuild groups
        let newGrouped = Dictionary(grouping: inputs, by: { ($0.inputGroupName ?? "").trimmingCharacters(in: .whitespaces) })
        grouped = newGrouped
        
        let known = Set(groups.map { $0.name.trimmingCharacters(in: .whitespaces) })
        let needed = Set(newGrouped.keys).subtracting(known)
        
        if !needed.isEmpty {
            groups.append(contentsOf: needed.map {
                SceneInputGroup(
                    name: $0,
                    note: $0.isEmpty ? "Ungrouped inputs" : nil,
                    background: .secondary,
                    isVisible: true,
                    isExpanded: true
                )
            })
        }
    }
}

struct InputsGrid: View, Equatable {
    static func == (l: Self, r: Self) -> Bool {
        return false
    }
    
    let inputs: [SceneInput]
    @Binding var groups: [SceneInputGroup]
    @StateObject private var model = InputsGridModel()
    
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            InputGroupColumn(
                group: bindingFor(name: "", in: $groups),
                inputs: model.grouped[""] ?? [],
                titleOverride: "General"
            )

            // compute indices in the ORIGINAL groups array
            let declaredIndices = groups.indices.filter {
                let g = groups[$0]
                return !g.name.isEmpty && g.isVisible
            }

            ForEach(declaredIndices, id: \.self) { i in
                let g = $groups[i]
                InputGroupColumn(
                    group: g,
                    inputs: model.grouped[g.wrappedValue.name] ?? [],
                    titleOverride: nil
                )
                .id(g.wrappedValue.name)
            }
        }
        .task(id: inputs.map(\.id)) {
            model.update(inputs: inputs, groups: &groups)
        }
        .onChange(of: inputs) { _, _ in
            model.update(inputs: inputs, groups: &groups)
        }
    }
    
    private func bindingFor(name: String, in groups: Binding<[SceneInputGroup]>) -> Binding<SceneInputGroup> {
        if let idx = groups.wrappedValue.firstIndex(where: { $0.name == name }) {
            return groups[idx]
        } else {
            return .constant(SceneInputGroup(name: name, isVisible: true, isExpanded: true))
        }
    }
}
