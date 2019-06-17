Swift client for OpenStreetMap Overpass API.

Uses @functionBuilder to provide in-language DSL for query construction and Combine framework to propagate results.

Example request (this will select roads in the coordinate bounding box):

```swift
    let request = OverpassRequest {
        Union {
            Query(.way) {
                BoundingBoxQuery(s: 51.248, w: 7.147, n: 51.252, e: 7.153)
                HasKV(key: "highway")
            }

            Recurse(.down)
        }

        Print()
    }
```

Another example (shelters adjacent to roads with bus stops):

```swift
    let request = OverpassRequest {
        Query(.node) {
            BoundingBoxQuery(s: 51.248, w: 7.147, n: 51.252, e: 7.153)
            HasKV(key: "highway", value: "bus_stop")
            HasKV(key: "shelter", value: "yes")
        }

        Print(.skeleton)
    }
```

Using client to send requests:

```swift
    let client = OverpassClient(URL(string: "https://lz4.overpass-api.de/api/interpreter")!)
    client.request(request).sink {
        print($0)
    }
```
