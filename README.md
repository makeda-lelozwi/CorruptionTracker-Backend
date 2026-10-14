# Corruption Tracker

## Public evidence web

The app presents the public parts of the Neo4j graph as browsable entity pages,
plain-language facts, nearby citations, and a small supporting graph. See
[docs/evidence_web.md](docs/evidence_web.md) for the implementation guide,
confirmed graph findings, wording rules, and test instructions.

## Neo4j Aura

The app keeps SQLite as its Active Record database and connects to Neo4j Aura
separately through the HTTPS Query API.

Set the connection details using environment variables:

```sh
export NEO4J_URI="neo4j+s://your-instance-id.databases.neo4j.io"
export NEO4J_USERNAME="neo4j"
export NEO4J_PASSWORD="your-password"
export NEO4J_DATABASE="neo4j"
```

Environment variables take precedence over encrypted Rails credentials. To use
encrypted credentials instead, run:

```sh
bin/rails credentials:edit
```

```yaml
neo4j:
  connection_uri: neo4j+s://your-instance-id.databases.neo4j.io
  username: neo4j
  password: your-password
  database: neo4j
```

`NEO4J_DATABASE` and the `database` credential are optional and default to
`neo4j`. Verify the connection from the same terminal where the environment
variables were exported:

```sh
bin/rails neo4j:verify
```

Run parameterized Cypher from application code with:

```ruby
Neo4j::Client.new.query(
  "MATCH (person:Person {id: $id}) RETURN person",
  parameters: { id: "123" }
)
```

Always pass application values through `parameters`; do not interpolate them
into the Cypher statement.

## Development

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
