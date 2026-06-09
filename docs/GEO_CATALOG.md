# Turbolapper Geography Catalog

All geographic identifiers used in the warehouse, with lookup patterns for LLM queries.

---

## County level (primary geography)

The warehouse covers **3,253 distinct US counties and county-equivalents** identified by 5-digit FIPS codes.

### FIPS code format

```
fips = state_fips (2 digits) || county_fips (3 digits)
```

Always stored as a zero-padded VARCHAR string. Examples:
- `'06037'` — Los Angeles County, CA
- `'17031'` — Cook County, IL (Chicago)
- `'36061'` — New York County (Manhattan), NY

### Looking up a county by name

```sql
-- Find FIPS for a named county
SELECT DISTINCT fips, county_name, state_fips
FROM semantic.county_unified
WHERE county_name ILIKE '%Travis%'   -- Austin, TX area

-- All counties in a state
SELECT DISTINCT fips, county_name
FROM semantic.county_unified
WHERE state_fips = '48'   -- Texas
ORDER BY county_name
```

### County name format

County names in BEA data follow the pattern `"County Name, ST"` (e.g., `'Harris, TX'`).
Some Virginia entries are combined city-county jurisdictions: `'Fairfax, Fairfax City + Falls Church, VA*'`.

### Well-known county FIPS reference

| FIPS | County | State |
|---|---|---|
| `04013` | Maricopa (Phoenix) | AZ |
| `06037` | Los Angeles | CA |
| `06041` | Marin | CA |
| `06073` | San Diego | CA |
| `06085` | Santa Clara (San Jose) | CA |
| `08031` | Denver | CO |
| `08097` | Pitkin (Aspen) | CO |
| `11001` | District of Columbia | DC |
| `12086` | Miami-Dade | FL |
| `12057` | Hillsborough (Tampa) | FL |
| `12095` | Orange (Orlando) | FL |
| `13121` | Fulton (Atlanta) | GA |
| `17031` | Cook (Chicago) | IL |
| `25017` | Middlesex (Boston area) | MA |
| `26163` | Wayne (Detroit) | MI |
| `27053` | Hennepin (Minneapolis) | MN |
| `32003` | Clark (Las Vegas) | NV |
| `36047` | Kings (Brooklyn) | NY |
| `36061` | New York (Manhattan) | NY |
| `36081` | Queens | NY |
| `37119` | Mecklenburg (Charlotte) | NC |
| `39035` | Cuyahoga (Cleveland) | OH |
| `39049` | Franklin (Columbus) | OH |
| `39061` | Hamilton (Cincinnati) | OH |
| `40143` | Tulsa | OK |
| `41051` | Multnomah (Portland) | OR |
| `42101` | Philadelphia | PA |
| `47037` | Davidson (Nashville) | TN |
| `47157` | Shelby (Memphis) | TN |
| `48029` | Bexar (San Antonio) | TX |
| `48113` | Dallas | TX |
| `48141` | El Paso | TX |
| `48201` | Harris (Houston) | TX |
| `48329` | Midland (Permian Basin) | TX |
| `48439` | Tarrant (Fort Worth) | TX |
| `48453` | Travis (Austin) | TX |
| `49035` | Salt Lake | UT |
| `49043` | Summit (Park City) | UT |
| `51059` | Fairfax | VA |
| `53033` | King (Seattle) | WA |
| `53061` | Snohomish | WA |
| `55079` | Milwaukee | WI |
| `56039` | Teton (Jackson Hole) | WY |

---

## State level

State FIPS codes (`state_fips`, 2-digit VARCHAR):

| FIPS | State | | FIPS | State | | FIPS | State |
|---|---|---|---|---|---|---|---|
| `01` | Alabama | | `19` | Iowa | | `37` | North Carolina |
| `02` | Alaska | | `20` | Kansas | | `38` | North Dakota |
| `04` | Arizona | | `21` | Kentucky | | `39` | Ohio |
| `05` | Arkansas | | `22` | Louisiana | | `40` | Oklahoma |
| `06` | California | | `23` | Maine | | `41` | Oregon |
| `08` | Colorado | | `24` | Maryland | | `42` | Pennsylvania |
| `09` | Connecticut | | `25` | Massachusetts | | `44` | Rhode Island |
| `10` | Delaware | | `26` | Michigan | | `45` | South Carolina |
| `11` | District of Columbia | | `27` | Minnesota | | `46` | South Dakota |
| `12` | Florida | | `28` | Mississippi | | `47` | Tennessee |
| `13` | Georgia | | `29` | Missouri | | `48` | Texas |
| `15` | Hawaii | | `30` | Montana | | `49` | Utah |
| `16` | Idaho | | `31` | Nebraska | | `50` | Vermont |
| `17` | Illinois | | `32` | Nevada | | `51` | Virginia |
| `18` | Indiana | | `33` | New Hampshire | | `53` | Washington |
| | | | `34` | New Jersey | | `54` | West Virginia |
| | | | `35` | New Mexico | | `55` | Wisconsin |
| | | | `36` | New York | | `56` | Wyoming |

```sql
-- All counties in California
SELECT fips, county_name FROM semantic.county_unified
WHERE state_fips = '06'
GROUP BY fips, county_name ORDER BY county_name

-- State-level aggregation: total GDP by state in 2022
SELECT state_fips, SUM(gdp_dollars) AS state_gdp
FROM semantic.county_unified
WHERE year = 2022 AND gdp_dollars IS NOT NULL
GROUP BY state_fips ORDER BY state_gdp DESC
```

---

## Virginia combined jurisdictions

BEA combines some Virginia independent cities with adjacent counties into single reporting units (marked with `*` suffix). The FIPS codes for these start with `519xx`:

```sql
-- Virginia combined FIPS units
SELECT DISTINCT fips, county_name
FROM semantic.county_unified
WHERE state_fips = '51' AND county_name LIKE '%*'
ORDER BY fips
```

These should be treated as single geographic units in all queries.

---

## CPI and average price geographies

The `cpi_monthly` and `avg_price_monthly` tables use BLS metro/regional area codes, **not FIPS codes**. They do not join to county tables.

### Metro areas with city-level CPI data

| Area name | Code type |
|---|---|
| Atlanta-Sandy Springs-Roswell, GA | MSA |
| Baltimore-Columbia-Towson, MD | MSA |
| Boston-Cambridge-Newton, MA-NH | MSA |
| Chicago-Naperville-Elgin, IL-IN-WI | MSA |
| Cincinnati-Hamilton, OH-KY-IN | MSA |
| Cleveland-Akron, OH | MSA |
| Dallas-Fort Worth-Arlington, TX | MSA |
| Denver-Aurora-Lakewood, CO | MSA |
| Detroit-Warren-Dearborn, MI | MSA |
| Houston-The Woodlands-Sugar Land, TX | MSA |
| Kansas City, MO-KS | MSA |
| Los Angeles-Long Beach-Anaheim, CA | MSA |
| Miami-Fort Lauderdale-West Palm Beach, FL | MSA |
| Milwaukee-Racine, WI | MSA |
| Minneapolis-St.Paul-Bloomington, MN-WI | MSA |
| New York-Newark-Jersey City, NY-NJ-PA | MSA |
| Philadelphia-Camden-Wilmington, PA-NJ-DE-MD | MSA |
| Phoenix-Mesa-Scottsdale, AZ | MSA |
| Pittsburgh, PA | MSA |
| Portland-Salem, OR-WA | MSA |
| Riverside-San Bernardino-Ontario, CA | MSA |
| San Diego-Carlsbad, CA | MSA |
| San Francisco-Oakland-Hayward, CA | MSA |
| Seattle-Tacoma-Bellevue WA | MSA |
| St. Louis, MO-IL | MSA |
| Tampa-St. Petersburg-Clearwater, FL | MSA |
| Washington-Arlington-Alexandria, DC-VA-MD-WV | MSA |
| U.S. city average | National |
| Urban Alaska | Regional |
| Urban Hawaii | Regional |

### Census regions and size classes

| Area name | Meaning |
|---|---|
| Northeast | BLS Northeast region |
| Midwest | BLS Midwest region |
| South | BLS South region |
| West | BLS West region |
| Northeast - Size Class A | Northeast, metros > 1.5M population |
| Northeast - Size Class B/C | Northeast, metros 50K–1.5M |
| Midwest - Size Class A | Midwest, metros > 1.5M |
| Midwest - Size Class B/C | Midwest, metros 50K–1.5M |
| Midwest - Size Class D | Midwest, non-metro areas |
| South - Size Class A | South, metros > 1.5M |
| South - Size Class B/C | South, metros 50K–1.5M |
| South - Size Class D | South, non-metro areas |
| West - Size Class A | West, metros > 1.5M |
| West - Size Class B/C | West, metros 50K–1.5M |
| East North Central | IL, IN, MI, OH, WI |
| East South Central | AL, KY, MS, TN |
| Middle Atlantic | NJ, NY, PA |
| Mountain | AZ, CO, ID, MT, NV, NM, UT, WY |
| New England | CT, ME, MA, NH, RI, VT |
| Pacific | AK, CA, HI, OR, WA |
| West North Central | IA, KS, MN, MO, NE, ND, SD |
| West South Central | AR, LA, OK, TX |

```sql
-- National CPI inflation for 2024
SELECT year, AVG(yoy_inflation_pct) AS avg_inflation
FROM semantic.cpi_monthly
WHERE is_us_city_average AND is_headline_all_items AND year = 2024
GROUP BY year

-- Compare food inflation: NYC vs national in 2023
SELECT area_name, ROUND(AVG(yoy_inflation_pct), 2) AS avg_food_inflation
FROM semantic.cpi_monthly
WHERE is_food AND year = 2023
  AND area_name IN ('U.S. city average', 'New York-Newark-Jersey City, NY-NJ-PA')
GROUP BY area_name
```

---

## Common geographic query patterns

```sql
-- Find a county by partial name
SELECT DISTINCT fips, county_name, state_fips
FROM semantic.county_unified
WHERE LOWER(county_name) LIKE '%orange%'

-- All counties in a multi-state region (e.g., Mountain West)
SELECT DISTINCT fips, county_name
FROM semantic.county_unified
WHERE state_fips IN ('04','08','16','30','32','35','49','56')

-- Top 10 boomtowns in the Sun Belt in 2022
SELECT fips, county_name, state_fips
FROM semantic.county_all_flags
WHERE year = 2022
  AND state_fips IN ('04','12','13','22','28','37','40','45','47','48','51')
  AND is_boomtown IS TRUE
ORDER BY county_name

-- Compare two specific counties
SELECT fips, county_name, year, personal_income_per_hh, gdp_per_hh, dominant_sector
FROM semantic.county_all_flags
WHERE fips IN ('48453', '06037')   -- Travis (Austin) vs LA County
  AND year = 2022
```

---

## Year coverage by geography

| Data | Counties | Years |
|---|---|---|
| GDP + industry sectors | 3,126 counties | 2001–2024 |
| Personal income + per-capita income | 3,148 counties | 1969–2024 |
| Population (BEA-derived) | 3,148 counties | 1969–2024 |
| IRS AGI + wages | 3,203 counties | 2015–2022 |
| Census population + migration | 3,143 counties | 2020–2024 |
| Household-normalized metrics | 3,253 counties | 1969–2024 (HH metrics null before IRS coverage) |
| All flags (county_all_flags) | 3,253 counties | 1969–2024 (many flags null outside source coverage) |

**Best year for full cross-source analysis:** 2022 — all four sources overlap, most flags non-null.
