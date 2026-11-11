# Local data exports

Put manually saved HTML/JSON files here. The backend reads this directory on
every phone-search run. In Docker/Render the path is `/app/data`; locally it is
`data/`. The directory is controlled by `MC1H_LOCAL_DATA`.

## File naming

The filename must contain the phone digits. Supported examples:

```text
data/avito_79990000001.html
data/avito_79990000001.json
data/youla_79990000001.html
data/youla_79990000001.json
data/phone_79990000001.json
data/79990000001.json
```

The full number is never written to the graph/provenance: file paths in reports
are masked as `local://data/avito_*********01.html`.

## JSON formats

A JSON file can be a list of records:

```json
[
  {
    "title": "iPhone 13",
    "url": "https://www.avito.ru/moskva/telefony/apple_iphone_13_123456789",
    "price": 50000,
    "description": "Public listing export"
  }
]
```

Or an object with one of these containers:

```json
{
  "items": [
    {
      "name": "Samsung Galaxy S21",
      "link": "https://www.avito.ru/moskva/telefony/samsung_galaxy_s21_987654321",
      "price": "30 000 ₽"
    }
  ]
}
```

Recognized containers: `items`, `results`, `listings`, `ads`, `offers`,
`records`, `products`, `entries`, `data`, `@graph`, `itemListElement`.

Recognized title fields: `title`, `name`, `headline`, `summary`.
Recognized URL fields: `url`, `link`, `permalink`, `href`.
Optional fields: `price`, `description`, `source`/`site`/`platform`.

Records are added to the graph with `observed_in` edges and confidence `0.45`.
They are observations, not proof of ownership. Malformed or empty files are
reported as explicit gaps.

## Privacy

Do not upload full passport/СНИЛС/ВУ numbers or other sensitive documents here.
The parser may read locally provided files, but reports store only masks and
hashes for those selector types. Prefer minimal, already-public exports.