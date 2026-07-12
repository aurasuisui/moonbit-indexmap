// Example: JSON serialization with preserved key order.
//
// Unlike MoonBit's built-in Map, IndexMap's ToJson implementation
// preserves insertion order. This is critical for APIs where
// field order matters (e.g., human-readable config, canonical JSON).
//
// Usage (in your project's moon.mod.json):
//   { "dependencies": { "aurasuisui/indexmap": "0.2.0" } }

///|
fn main {
  // ---- IndexMap preserves key order in JSON ----
  let ordered = @indexmap.new()
  ordered.insert("name", "MoonBit IndexMap") |> ignore
  ordered.insert("version", "0.2.0") |> ignore
  ordered.insert("license", "Apache-2.0") |> ignore
  ordered.insert("author", "aurasuisui") |> ignore

  let ordered_json = ordered.to_json()
  println("=== IndexMap (order preserved) ===")
  println(@debug.to_string(ordered_json))
  // Output keys in order: name, version, license, author

  // ---- Built-in Map does NOT preserve order ----
  let unordered : Map[String, Json] = Map([])
  unordered["name"] = Json::string("MoonBit IndexMap")
  unordered["version"] = Json::string("0.2.0")
  unordered["license"] = Json::string("Apache-2.0")
  unordered["author"] = Json::string("aurasuisui")

  let unordered_json = Json::object(unordered)
  println("=== Built-in Map (order not guaranteed) ===")
  println(@debug.to_string(unordered_json))
  // Keys may appear in any order

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
