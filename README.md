# SA Local Government Councillors

A [morph.io](https://morph.io) scraper that collects the name, contact details, role, and ward of every elected member across all 68 local councils in South Australia.

Forked from [openaustralia/sa_lg_councillors](https://github.com/openaustralia/sa_lg_councillors). The original scraper used a deprecated GovHack Parse API. This version scrapes council websites directly.

## Data

One row per elected member. Unique key: `council` + `name`.

Column | Description
--- | ---
`name` | Full name of the elected member
`role` | Mayor, Deputy Mayor, Councillor, or Chairperson
`ward` | Ward name, if the council uses wards (null for at-large members and for Mayors)
`council` | Full council name
`email` | Official council email address
`phone` | Contact phone number
`url` | Profile page URL on the council website
`source_url` | The page that was scraped

## Coverage

Councillor data for all 68 SA councils is publicly available — councils are required to publish it under the Local Government Act 1999 (SA).

Status | Count | Notes
--- | --- | ---
Implemented | 23 | OpenCities CMS family (22) + Port Adelaide Enfield
TODO | 45 | Logged and skipped at runtime

See `scraper.rb` for the current status of each council.

## How it works

Most SA metro councils run the same CMS — OpenCities by Granicus — which means one scraping function covers around a third of all councils. Remaining councils are implemented individually, grouped by CMS family where possible.

Shared helpers handle email extraction, phone normalisation, role detection, and name cleaning across all scrapers. Any council that fails to fetch or parse logs a clear warning and the run continues.

## Running locally

```
gem install scraperwiki mechanize nokogiri
ruby scraper.rb
```

Results are written to `data.sqlite` in the local directory.

## Notes

- Roxby Downs is included in the council list but does not participate in standard local government elections. It is governed by a municipal council appointed by BHP.
- The 2026 SA council elections are scheduled for later this year. Councillor data will change significantly after polling day and the scraper will need a re-run.
- Some smaller rural councils have minimal web infrastructure. The `members_url` values for TODO councils are best guesses and may need correcting on inspection.
