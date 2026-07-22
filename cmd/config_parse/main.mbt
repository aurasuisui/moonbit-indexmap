// Example: Configuration file parser with order-preserving key-value pairs.
//
// Usage (in your project's moon.mod.json):
//   { "dependencies": { "aurasuisui/indexmap": "0.3.3" } }
//
// MoonBit's built-in Map doesn't preserve insertion order. When parsing
// a config file, you want keys to appear in the same order the user wrote them.
// IndexMap solves this.

///|
/// Parse a simple key=value config string into an IndexMap,
/// preserving the order keys appear in the input.
fn parse_config(config_text : String) -> @indexmap.IndexMap[String, String] {
  let map = @indexmap.new()
  let lines = config_text.split("\n").collect()
  let mut i = 0
  while i < lines.length() {
    let line = lines[i].trim()
    if line != "" && !line.has_prefix("#") {
      let parts = line.split("=").collect()
      if parts.length() >= 2 {
        let key = parts[0].trim().to_owned()
        let value = parts[1].trim().to_owned()
        map.insert(key, value) |> ignore
      }
    }
    i = i + 1
  }
  map
}

///|
fn main {
  let config = parse_config(
    (
      #|server.host = 0.0.0.0
      #|server.port = 8080
      #|database.url = postgres://localhost:5432/mydb
      #|database.pool_size = 10
      #|logging.level = debug
      #|logging.format = json
    ),
  )

  // Iteration preserves the exact order from the config file
  let iter = config.iter()
  while true {
    match iter.next() {
      Some((k, v)) => println(k + " = " + v)
      None => break
    }
  }
  // Output:
  // server.host = 0.0.0.0
  // server.port = 8080
  // database.url = postgres://localhost:5432/mydb
  // database.pool_size = 10
  // logging.level = debug
  // logging.format = json

  // Access a specific key
  match config.get("server.port") {
    Some(port) => println("Server will listen on port " + port)
    None => println("port not configured")
  }

  // Use entry API for conditional update
  match config.entry("server.host") {
    @indexmap.Occupied(entry) => println("Host configured: " + entry.get())
    @indexmap.Vacant(_) => println("No host configured, using default")
  }
}
