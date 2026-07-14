# Public evidence web

This guide explains which part of the evidence-web plan each change implements,
how the pieces work together, and how to check them. It is written for someone
who is new to this application.

## Confirmed graph findings

The implementation was based on the six read-only audit exports in `tmp/`.
Those files are local audit inputs and are not application dependencies.

The audit confirmed:

- 41 relationship types and 58 exact source/relationship/target patterns.
- 138 total relationships.
- The 20 most common patterns contain 88 relationships, or 63.8% of the graph.
- 28 people, 21 organisations, 26 events, 19 allegations, 11 evidence nodes,
  and 3 testimonies are public.
- All 108 public nodes have a non-empty, unique `externalId`.
- Public nodes each have one public label in the current data.
- Internal-only labels are `Chunk`, `Document`, and `__Entity__`. There is also
  one node with no label. None of these appear in public navigation.
- Relationship citations use `quote` and `page`. Approved supporting fields are
  `role`, `position`, `note`, `reason`, and `status`.
- Public descriptions use `description`; testimonies use `summary`.

These are confirmed graph findings. Any wording for patterns outside the table
below is a cautious application fallback, not an interpretation of the graph.

## Request and data flow

For a normal entity page, the data moves through the app like this:

1. A typed route, such as `/people/:external_id`, fixes the public node label.
2. `PublicEntitiesController` validates the external ID before doing any query.
3. `PublicEntityRepository` asks Neo4j for the entity and its one-hop public
   relationships.
4. `PublicGraphFactBuilder` converts each relationship into a normalized fact.
5. The ERB page renders facts first, grouped into narrative lanes.
6. `PublicEntityGraph` reuses those facts to build a maximum 25-node graph.
7. `public_graph_controller.js` renders the supporting Cytoscape view.

SQLite is not involved in this flow and no database migration was added.

## Public entity foundation

This implements the plan's six-label whitelist and shared typed routes.

Main files:

- `app/services/public_entity_catalog.rb`
- `app/services/public_entity_repository.rb`
- `app/controllers/public_entities_controller.rb`
- `config/routes.rb`

`PublicEntityCatalog` is the only list of labels allowed in public queries. It
also stores the singular name, plural name, index route, and detail route for
each type. Labels cannot be passed directly from an untrusted URL into Cypher.
Only a label fetched from this catalogue is inserted into a query. Search text
and external IDs remain Neo4j parameters.

The public routes are:

- `/testimonies` and `/testimonies/:external_id`
- `/people` and `/people/:external_id`
- `/organisations` and `/organisations/:external_id`
- `/events` and `/events/:external_id`
- `/allegations` and `/allegations/:external_id`
- `/evidence` and `/evidence/:external_id`

To add another public label later, first audit its IDs and properties, then add
one catalogue entry and its two typed routes. Do not accept a label supplied as
free text by a visitor.

## Home page, indexes, and search

This implements the grouped home index and type-specific browse pages.

Main files:

- `app/controllers/home_controller.rb`
- `app/views/home/show.html.erb`
- `app/views/public_entities/index.html.erb`

The home query loads all matching public entities once, groups them by label,
and sorts them by `name`, `title`, or `externalId`. Each home section shows its
matching count and the first six links. Sections appear in this order:

1. Testimonies
2. People
3. Organisations
4. Events
5. Allegations
6. Evidence

Search is case-insensitive and checks `name`, `title`, and `externalId`. A type
index uses the same rules but queries only its whitelisted label. Internal-only
nodes are excluded by comparing every node's labels with the public whitelist;
the implementation never assumes that `labels(node)[0]` is public.

If a group or search has no results, the page shows an empty-state message. If
Neo4j cannot be reached, the home page returns HTTP 502 with a safe message.

Manual check:

1. Open `/` and confirm six sections appear in the documented order.
2. Search for part of a name and then for part of an external ID.
3. Open each “View all” link and repeat a search on the type index.
4. Confirm no Chunk, Document, or `__Entity__` record appears.

## Normalized facts and wording

This implements the human-readable relationship layer.

Main file: `app/services/public_graph_fact_builder.rb`.

Each fact contains:

- a public sentence and narrative lane;
- source and target entity data with public paths;
- a nearby quote and page, when present;
- only approved role, position, note, reason, and status metadata;
- the original relationship type and full three-part pattern.

Template lookup always uses:

```text
[source label, relationship type, target label]
```

It never looks up wording from the relationship type alone. This matters for a
type such as `LED_TO`, which has separate Event-to-Allegation and Event-to-Event
wording.

### Audited top-20 wording table

“Reverse” means that the target is mentioned before the source to make the
sentence easier to read. The graph direction itself is never changed.

| # | Exact pattern | Count | Lane | Display | Sentence template | Confirmed supporting fields |
|---:|---|---:|---|---|---|---|
| 1 | Testimony → DISCUSSES → Allegation | 11 | Testimony and sources | Forward | Source discusses the allegation “Target”. | None |
| 2 | Event → LED_TO → Allegation | 10 | Events and causality | Forward | The dataset records Source as leading to the allegation “Target”. | page, quote, reason |
| 3 | Person → WORKS_FOR → Organisation | 10 | Roles and affiliations | Forward | Source is recorded as working for Target. | note, page, position, quote, role |
| 4 | Event → INVOLVES → Person | 6 | Events and causality | Reverse | Target is recorded as involved in Source. | role |
| 5 | Person → ASSOCIATE_OF → Person | 5 | Roles and affiliations | Forward | Source is recorded as associated with Target. | page, quote |
| 6 | Evidence → SUPPORTS → Allegation | 4 | Evidence | Forward | Source is recorded as supporting the allegation “Target”. | reason |
| 7 | Person → SUBJECT_OF → Allegation | 4 | Allegations and complaints | Forward | Source is recorded as the subject of the allegation “Target”. | page, quote |
| 8 | Person → USED_INTERMEDIARY → Person | 4 | Other connections | Forward | Source is recorded as having used Target as an intermediary. | reason |
| 9 | Testimony → DISCUSSES → Event | 4 | Testimony and sources | Forward | Source discusses the event “Target”. | page, quote |
| 10 | Event → LED_TO → Event | 3 | Events and causality | Forward | The dataset records Source as leading to Target. | reason |
| 11 | Organisation → INVESTIGATED → Event | 3 | Events and causality | Forward | Source is recorded as having investigated Target. | role |
| 12 | Organisation → RECEIVED_COMPLAINT → Event | 3 | Allegations and complaints | Forward | Source is recorded as having received a complaint connected with Target. | status |
| 13 | Organisation → SUBJECT_OF → Allegation | 3 | Allegations and complaints | Forward | Source is recorded as the subject of the allegation “Target”. | None |
| 14 | Person → ALLEGED_MEMBER_OF → Organisation | 3 | Roles and affiliations | Forward | Source is alleged in the dataset to be a member of Target. | None |
| 15 | Person → MURDERED → Event | 3 | Events and causality | Forward | Source is connected to Target through a relationship recorded as MURDERED. | None |
| 16 | Person → SENT_INFORMATION → Event | 3 | Communication | Forward | Source is recorded as having sent information connected with Target. | page, quote, role |
| 17 | Testimony → GIVEN_BY → Person | 3 | Testimony and sources | Forward | Source is recorded as having been given by Target. | page, quote |
| 18 | Allegation → BROUGHT_COMPLAINT → Organisation | 2 | Allegations and complaints | Forward | Source is recorded as a complaint brought to Target. | None |
| 19 | Event → INFORMED → Person | 2 | Communication | Forward | Source is recorded as having informed Target. | reason |
| 20 | Event → INVESTIGATED → Person | 2 | Events and causality | Reverse | Target is recorded as investigated in Source. | page, quote, role |

The audited `Event → VICTIM → Person` pattern also has the requested reversed
template: “Person was the victim in Event.”

An unlisted pattern uses this exact shape:

```text
Source is connected to Target through RELATIONSHIP.
```

To add a template, verify the exact pattern and supporting properties against
Neo4j, add one entry to `TEMPLATES`, and add a wording test. Keep legal qualifiers
such as “alleged” when the stored data or node title uses them.

## Entity details and narrative lanes

This implements text-first entity pages and nearby support.

Main files:

- `app/views/public_entities/show.html.erb`
- `app/views/public_entities/_fact.html.erb`

The page uses the node's stored description or testimony summary when present.
Otherwise it gives a neutral explanation of what the page contains. It does not
generate a biography from guesses.

Facts are grouped into:

- Testimony and sources
- Evidence
- Allegations and complaints
- Communication
- Roles and affiliations
- Events and causality
- Procurement and ownership
- Other connections

The first three facts in each lane are visible immediately. Further facts use a
native `<details>` element, so they work without custom JavaScript. Quotes and
pages sit inside the fact card they support. The relationship-details control
shows the exact pattern for transparency.

If an entity has no public relationships, its page remains available and shows
an explanation instead of an empty graph. Version one does not traverse Chunk
or Document nodes for more citations.

Manual check:

1. Open an entity with more than three facts in one lane.
2. Expand “Show more” using both a mouse and keyboard.
3. Confirm source and target links open typed public pages.
4. Confirm quotes, pages, and metadata appear inside the correct fact card.

## Supporting graph

This implements the graph-second part of the plan.

Main files:

- `app/services/public_entity_graph.rb`
- `app/javascript/controllers/public_graph_controller.js`

The service builds graph data from the same normalized facts shown above it. It
does not run a second graph query. It includes the focus node and at most 24
unique related nodes, for 25 total. An omission message appears when the written
facts include more related nodes.

Cytoscape preserves relationship source and target IDs. Selecting a node opens
its typed public page. If JavaScript fails, an error appears in the graph area
while all written facts and normal links remain usable.

The old person dropdown, person-only JSON endpoints, controller, view, narrative
service, and Stimulus controller were removed because this shared flow replaces
them.

## Styling

This implements only the evidence-web layout in
`app/assets/stylesheets/application.css` and the small site wrapper in the
application layout.

The stylesheet covers search, grouped indexes, fact lanes, citations, metadata,
empty/error notices, and the supporting graph. The two-column home layout becomes
one column on smaller screens.

The base font size is 14px. Measurements derived from pixels were divided by 14
and rounded to the nearest 0.1rem. For example, the 480px graph height becomes
34.3rem. Cytoscape values use the browser's root font size as the same conversion
base.

## Failure handling

| Situation | Public behavior |
|---|---|
| Invalid external ID | HTTP 404 without querying Neo4j |
| Valid but missing entity | HTTP 404 |
| Neo4j request failure | HTTP 502 with a safe message |
| Empty index or search | Normal page with an empty-state message |
| Entity with no public facts | Entity remains available with an explanation |
| Graph JavaScript failure | Written page remains usable; graph error is shown |

Neo4j error classes are logged, but credentials, query details, and returned
private messages are not rendered.

## Tests

Focused coverage is in:

- `test/services/public_graph_fact_builder_test.rb`
- `test/controllers/home_controller_test.rb`
- `test/controllers/public_entities_controller_test.rb`

The tests cover exact-pattern wording, same-type/different-pattern wording,
reversal, fallback text, metadata filtering, citations, escaping, grouped home
content, typed pages, invalid and missing IDs, safe Neo4j errors, and the 25-node
graph limit. The old broken `home_show_url` test now checks the real root route.

Run everything with the repository's Ruby version:

```sh
mise x ruby@3.4.9 -- bin/rails test
```

Also check autoloading and style:

```sh
mise x ruby@3.4.9 -- bin/rails zeitwerk:check
mise x ruby@3.4.9 -- bin/rubocop
```
