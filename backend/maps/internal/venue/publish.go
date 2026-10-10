package venue

import (
	"fmt"
	"slices"
)

// Issue is a publish-time problem. Errors block publishing; warnings don't.
type Issue struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	FloorID   string `json:"floorId,omitempty"`
	FeatureID string `json:"featureId,omitempty"`
}

// CheckPublish validates a whole draft map. It re-runs per-object validation
// (the floor may have changed since a feature was saved) and checks the
// routing graph as a whole.
func CheckPublish(m *Map) (errs, warnings []Issue) {
	if len(m.Floors) == 0 {
		errs = append(errs, Issue{Code: "no_floors", Message: "add at least one floor before publishing"})
	}
	for i := range m.Graphs {
		g := &m.Graphs[i]
		f := m.Floor(g.FloorID)
		if f == nil {
			continue // orphaned graph of a deleted floor; ignored
		}
		if err := ValidateGraph(g, f); err != nil {
			errs = append(errs, Issue{Code: "invalid_graph", Message: err.Error(), FloorID: f.ID})
		}
	}

	comp := components(m)
	// The main component is the one containing the most entrance nodes.
	count := map[int]int{}
	for _, ft := range m.Features {
		if c, ok := comp[nodeKey{ft.FloorID, ft.EntranceNodeID}]; ok && ft.EntranceNodeID != "" {
			count[c]++
		}
	}
	main, best := -1, 0
	for c, n := range count {
		if n > best || (n == best && c < main) {
			main, best = c, n
		}
	}

	for i := range m.Features {
		ft := &m.Features[i]
		f := m.Floor(ft.FloorID)
		if err := ValidateFeature(ft, f); err != nil {
			errs = append(errs, Issue{Code: "invalid_feature", Message: err.Error(), FeatureID: ft.ID, FloorID: ft.FloorID})
			continue
		}
		if ft.Type != TypeRoom && ft.Type != TypeStand && ft.Type != TypeMarker {
			continue // POIs are routable only if they have an entrance node
		}
		switch c, ok := comp[nodeKey{ft.FloorID, ft.EntranceNodeID}]; {
		case ft.EntranceNodeID == "":
			warnings = append(warnings, Issue{Code: "no_entrance", Message: fmt.Sprintf("%q has no entrance node; routing to it is not possible", ft.Name), FeatureID: ft.ID, FloorID: ft.FloorID})
		case !ok:
			errs = append(errs, Issue{Code: "unknown_entrance", Message: fmt.Sprintf("%q references entrance node %q that is not in the floor's graph", ft.Name, ft.EntranceNodeID), FeatureID: ft.ID, FloorID: ft.FloorID})
		case c != main:
			warnings = append(warnings, Issue{Code: "unreachable", Message: fmt.Sprintf("%q is not connected to the rest of the walkway graph", ft.Name), FeatureID: ft.ID, FloorID: ft.FloorID})
		}
	}
	return errs, warnings
}

type nodeKey struct{ floor, node string }

// components labels every node with its connected component across floors.
func components(m *Map) map[nodeKey]int {
	parent := map[nodeKey]nodeKey{}
	var find func(nodeKey) nodeKey
	find = func(k nodeKey) nodeKey {
		for parent[k] != k {
			parent[k] = parent[parent[k]]
			k = parent[k]
		}
		return k
	}
	union := func(a, b nodeKey) {
		if _, ok := parent[a]; !ok {
			return
		}
		if _, ok := parent[b]; !ok {
			return
		}
		parent[find(a)] = find(b)
	}
	connectors := map[string][]nodeKey{}
	for _, g := range m.Graphs {
		if m.Floor(g.FloorID) == nil {
			continue
		}
		for _, n := range g.Nodes {
			k := nodeKey{g.FloorID, n.ID}
			parent[k] = k
			if n.Connector != "" {
				connectors[n.Connector] = append(connectors[n.Connector], k)
			}
		}
	}
	for _, g := range m.Graphs {
		for _, e := range g.Edges {
			union(nodeKey{g.FloorID, e.From}, nodeKey{g.FloorID, e.To})
		}
	}
	for _, ks := range connectors {
		for _, k := range ks[1:] {
			union(ks[0], k)
		}
	}
	// Stable component numbering.
	keys := make([]nodeKey, 0, len(parent))
	for k := range parent {
		keys = append(keys, k)
	}
	slices.SortFunc(keys, func(a, b nodeKey) int {
		if a.floor != b.floor {
			if a.floor < b.floor {
				return -1
			}
			return 1
		}
		switch {
		case a.node < b.node:
			return -1
		case a.node > b.node:
			return 1
		}
		return 0
	})
	ids := map[nodeKey]int{}
	out := make(map[nodeKey]int, len(keys))
	for _, k := range keys {
		r := find(k)
		id, ok := ids[r]
		if !ok {
			id = len(ids)
			ids[r] = id
		}
		out[k] = id
	}
	return out
}
