// Example: JSON serialization with preserved key order.
//
// IndexMap's ToJson implementation preserves insertion order, which is critical
// for APIs where field order matters (e.g., human-readable config, canonical
// JSON). Current MoonBit's built-in Map is also insertion-ordered; IndexMap's
// edge is index-based access (get_index / first / last / pop) plus an Entry API.
//
// Usage (in your project's moon.mod.json):
//   { "dependencies": { "aurasuisui/indexmap": "0.3.3" } }

///|
fn main {
  // ---- IndexMap preserves key order in JSON ----
  let ordered = @indexmap.new()
  ordered.insert("name", "MoonBit IndexMap") |> ignore
  ordered.insert("version", "0.3.3") |> ignore
  ordered.insert("license", "Apache-2.0") |> ignore
  ordered.insert("author", "aurasuisui") |> ignore

  let ordered_json = ordered.to_json()
  println("=== IndexMap (order preserved) ===")
  println(@debug.to_string(ordered_json))
  // Output keys in order: name, version, license, author

  // ---- Built-in Map (also insertion-ordered in current MoonBit) ----
  let builtin_map : Map[String, Json] = Map([])
  builtin_map["name"] = Json::string("MoonBit IndexMap")
  builtin_map["version"] = Json::string("0.3.3")
  builtin_map["license"] = Json::string("Apache-2.0")
  builtin_map["author"] = Json::string("aurasuisui")

  let builtin_json = Json::object(builtin_map)
  println("=== Built-in Map (insertion-ordered too) ===")
  println(@debug.to_string(builtin_json))
  // Current MoonBit maps keep insertion order; IndexMap adds index access + Entry API

  // ---- IndexSet also preserves order in JSON ----
  let tags = @indexmap.IndexSet::new()
  tags.insert("hashmap") |> ignore
  tags.insert("indexmap") |> ignore
  tags.insert("ordered") |> ignore
  tags.insert("data-structure") |> ignore

  let tags_json = tags.to_json()
  println("=== IndexSet (order preserved) ===")
  println(@debug.to_string(tags_json))
  // Output: ["hashmap", "indexmap", "ordered", "data-structure"]

  // ---- Nested IndexMap example ----
  let nested = @indexmap.new()
  nested.insert("server", ordered_json) |> ignore
  nested.insert("tags", tags_json) |> ignore
  println("=== Nested (both layers preserve order) ===")
  println(@debug.to_string(nested.to_json()))
}
