"""
Fetch variety-wise daily market prices (AGMARKNET) from data.gov.in for the
36 image-model commodities, normalize them to the Agriculture_price_dataset.csv
column structure, and save to dataset/agmarknet_prices/agmarknet_api_data.csv.

Credentials are read from .env (DATA_GOV_API_KEY, DATA_GOV_RESOURCE_ID).
The API key is never printed, logged, or written anywhere.
"""

import os
import sys
import time
import re
import argparse
import pandas as pd
import requests
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_PATH = os.path.join(BASE_DIR, '.env')
OUTPUT_PATH = os.path.join(
    BASE_DIR, 'dataset', 'agmarknet_prices', 'agmarknet_api_data.csv'
)

API_BASE = 'https://api.data.gov.in/resource'

# Exact column layout of the existing Agriculture_price_dataset.csv
TARGET_COLUMNS = [
    'STATE', 'District Name', 'Market Name', 'Commodity', 'Variety',
    'Grade', 'Min_Price', 'Max_Price', 'Modal_Price', 'Price Date',
]

# Canonical target -> set of acceptable source-field names (normalized:
# lowercase, spaces/hyphens/underscores stripped) discovered at runtime.
FIELD_MATCHERS = {
    'STATE': {'state'},
    'District Name': {'districtname', 'district'},
    'Market Name': {'marketname', 'market'},
    'Commodity': {'commodity'},
    'Variety': {'variety'},
    'Grade': {'grade'},
    'Min_Price': {'minprice', 'min_x0020_price'},
    'Max_Price': {'maxprice', 'max_x0020_price'},
    'Modal_Price': {'modalprice'},
    'Price Date': {'pricedate', 'date', 'arrivaldate'},
}

# Near-synonym equivalence groups required by the spec. Each model crop maps
# to the dataset-side commodity substrings accepted as equivalent.
COMMODITY_SYNONYMS = {
    'apple': ['apple'],
    'banana': ['banana'],
    'beetroot': ['beetroot'],
    'bell pepper': ['bell pepper', 'capsicum'],
    'cabbage': ['cabbage'],
    'capsicum': ['capsicum'],
    'carrot': ['carrot'],
    'cauliflower': ['cauliflower'],
    'chilli pepper': ['chilli pepper', 'chilli'],
    'corn': ['corn', 'maize'],
    'cucumber': ['cucumber', 'kheera', 'kakri'],
    'eggplant': ['eggplant', 'brinjal'],
    'garlic': ['garlic'],
    'ginger': ['ginger'],
    'grapes': ['grapes'],
    'jalepeno': ['jalapeno', 'jalepeno'],
    'kiwi': ['kiwi'],
    'lemon': ['lemon'],
    'lettuce': ['lettuce'],
    'mango': ['mango'],
    'onion': ['onion'],
    'orange': ['orange'],
    'paprika': ['paprika'],
    'pear': ['pear'],
    'peas': ['peas'],
    'pineapple': ['pineapple'],
    'pomegranate': ['pomegranate'],
    'potato': ['potato'],
    'raddish': ['radish', 'raddish'],
    'soy beans': ['soyabean', 'soybean', 'soy beans'],
    'spinach': ['spinach'],
    'sweetcorn': ['sweet corn', 'sweetcorn', 'maize'],
    'sweetpotato': ['sweet potato', 'sweetpotato'],
    'tomato': ['tomato'],
    'turnip': ['turnip'],
    'watermelon': ['watermelon', 'water melon'],
}

PAGE_SIZE = 500          # records per page
MAX_PAGES_PER_QUERY = 3000   # hard safety cap against runaway pagination
REQUEST_DELAY_S = 1      # polite delay between API calls
RETRY_DELAYS = [2, 4, 8]     # exponential backoff
REQUEST_TIMEOUT_S = 90   # per-request read timeout
# Most-recent records fetched per commodity synonym variant. The resource
# holds ~81M historical rows (oldest 2009); fetching ALL history for 36
# commodities is infeasible, so we page the newest tail until the API
# returns zero records within that tail.
RECENT_CAP_PER_VARIANT = 10000


def redact(text, secret):
    """Return text with the API key replaced by *** (defensive logging)."""
    if not secret:
        return text
    return str(text).replace(secret, '***')


def norm_field(name):
    return re.sub(r'[\s_\-]+', '', str(name)).lower()


def require_env():
    load_dotenv(ENV_PATH)
    api_key = os.getenv('DATA_GOV_API_KEY')
    resource_id = os.getenv('DATA_GOV_RESOURCE_ID')
    missing = [k for k, v in [('DATA_GOV_API_KEY', api_key),
                              ('DATA_GOV_RESOURCE_ID', resource_id)] if not v]
    if missing:
        print('ERROR: missing required .env variables:',
              ', '.join(missing))
        print(f'Expected .env at: {ENV_PATH}')
        print('Create it with:')
        print('  DATA_GOV_API_KEY=<key>')
        print('  DATA_GOV_RESOURCE_ID=<resource-id>')
        sys.exit(2)
    return api_key, resource_id


def api_get(url, params, api_key):
    """GET with retry + exponential backoff. Raises on final failure."""
    headers = {'User-Agent': 'AgriMitraFetcher/1.0'}
    last_err = None
    for attempt in range(len(RETRY_DELAYS) + 1):
        try:
            resp = requests.get(
                url, params=params, timeout=REQUEST_TIMEOUT_S, headers=headers
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as exc:  # noqa: BLE001 - deliberate broad catch
            last_err = exc
            if attempt < len(RETRY_DELAYS):
                wait = RETRY_DELAYS[attempt]
                print(f'    attempt {attempt + 1} failed '
                      f'({type(exc).__name__}); retrying in {wait}s...')
                time.sleep(wait)
    raise RuntimeError(redact(last_err, api_key))


def fetch_page(resource_id, api_key, offset, limit, extra_filters=None):
    params = {
        'api-key': api_key,
        'format': 'json',
        'limit': limit,
        'offset': offset,
    }
    if extra_filters:
        params.update(extra_filters)
    data = api_get(f'{API_BASE}/{resource_id}', params, api_key)
    if not isinstance(data, dict):
        raise RuntimeError('unexpected non-dict API response')
    records = data.get('records') or []
    total = data.get('total')
    count = data.get('count')
    return records, total, count


def paginate(resource_id, api_key, extra_filters=None, label='', start_offset=0):
    """
    Page a query until the API returns zero records (or the reported total is
    reached). start_offset lets callers begin at a later point in the result
    set (used by fetch_variant_tail to grab only the most-recent window).
    """
    all_records = []
    offset = start_offset
    for _page in range(MAX_PAGES_PER_QUERY):
        records, total, _count = fetch_page(
            resource_id, api_key, offset, PAGE_SIZE, extra_filters
        )
        if not records:
            break
        all_records.extend(records)
        offset += len(records)
        if total is not None:
            try:
                if offset >= int(total):
                    break
            except (TypeError, ValueError):
                pass
        time.sleep(REQUEST_DELAY_S)
    print(f'    [{label}] fetched {len(all_records)} records '
          f'(offsets {start_offset}->{offset})')
    return all_records


def fetch_variant_tail(resource_id, api_key, commodity_value, label=''):
    """
    Fetch the most-recent window of records for one filtered commodity value.

    The full resource holds ~81M historical rows; per-commodity history can
    still be hundreds of thousands of rows. One cheap limit=1 call probes the
    filtered total T, then we page from max(0, T - RECENT_CAP_PER_VARIANT)
    until the API returns zero records at the end of that tail.
    """
    probe_records, total, _count = fetch_page(
        resource_id, api_key, 0, 1,
        extra_filters={'filters[commodity]': commodity_value},
    )
    try:
        t = int(total) if total is not None else 0
    except (TypeError, ValueError):
        print(f'    [{label}] unparseable total={total!r}; defaulting to probe page')
        return list(probe_records)

    if t <= len(probe_records):
        time.sleep(REQUEST_DELAY_S)
        print(f'    [{label}] small total={t}; fetched {len(probe_records)}')
        return list(probe_records)

    time.sleep(REQUEST_DELAY_S)
    start = max(0, t - RECENT_CAP_PER_VARIANT)
    return paginate(
        resource_id, api_key,
        extra_filters={'filters[commodity]': commodity_value},
        label=label,
        start_offset=start,
    )


def normalize_commodity(name):
    """lowercase + strip parenthetical qualifiers + collapse whitespace."""
    s = str(name).strip().lower()
    s = re.sub(r'\([^)]*\)', '', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s


def detect_field_mapping(sample_record):
    """Map actual API record keys onto TARGET_COLUMNS."""
    mapping = {}
    unmatched_targets = []
    src_keys = {norm_field(k): k for k in sample_record.keys()}
    for target, candidates in FIELD_MATCHERS.items():
        hit = next((src_keys[c] for c in candidates if c in src_keys), None)
        if hit is not None:
            mapping[target] = hit
        else:
            unmatched_targets.append(target)
    return mapping, unmatched_targets


def normalize_record(raw, mapping):
    row = {}
    for target in TARGET_COLUMNS:
        src = mapping.get(target)
        val = raw.get(src, '') if src else ''
        if target in ('Min_Price', 'Max_Price', 'Modal_Price'):
            cleaned = re.sub(r'[^\d.]', '', str(val))
            row[target] = cleaned if cleaned else ''
        else:
            row[target] = '' if val is None else str(val).strip()
    return row


def main():
    parser = argparse.ArgumentParser(
        description='Fetch AGMARKNET commodity prices from data.gov.in'
    )
    parser.add_argument(
        '--only', default='',
        help='comma-separated crop keys to process (default: all 36)'
    )
    parser.add_argument(
        '--append', action='store_true',
        help='append results to the output CSV instead of overwriting'
    )
    args = parser.parse_args()

    selected = COMMODITY_SYNONYMS
    if args.only:
        keys = [k.strip() for k in args.only.split(',') if k.strip()]
        unknown = [k for k in keys if k not in COMMODITY_SYNONYMS]
        if unknown:
            print(f'ERROR: unknown crop(s): {unknown}')
            sys.exit(1)
        selected = {k: COMMODITY_SYNONYMS[k] for k in keys}

    api_key, resource_id = require_env()

    print('=' * 64)
    print('AGMARKNET FETCH - data.gov.in variety-wise daily market prices')
    print('=' * 64)

    # ---- Test call (limit=5): inspect real response structure -------------
    print('\n[1/4] Test call (limit=5) to discover response structure...')
    records, total, count = fetch_page(resource_id, api_key, 0, 5)

    print(f'  records in page: {len(records)}')
    print(f'  total reported : {total}')
    print(f'  count reported : {count}')

    if not records:
        print('ERROR: test call returned zero records - cannot proceed.')
        sys.exit(3)

    print(f'  record fields  : {sorted(records[0].keys())}')
    mapping, unmatched = detect_field_mapping(records[0])
    print(f'  field mapping  :')
    for tgt in TARGET_COLUMNS:
        src = mapping.get(tgt)
        mark = 'OK ' if src else 'MISSING'
        print(f'    [{mark}] {tgt:<12} <- {src}')
    if unmatched:
        print(f'  WARNING: no source field found for: {unmatched}')

    commodity_src = mapping.get('Commodity')

    # ---- Detect server-side commodity filtering ---------------------------
    print('\n[2/4] Checking whether filters[commodity] is supported...')
    server_filter = False
    if commodity_src:
        try:
            probe, _, _ = fetch_page(
                resource_id, api_key, 0, 5,
                extra_filters={'filters[commodity]': 'Tomato'}
            )
            if probe:
                values = {
                    str(r.get(commodity_src, '')).strip().lower()
                    for r in probe
                }
                if all('tomato' in v for v in values):
                    server_filter = True
                    print('  SUPPORTED - filtered probe returned only Tomato records.')
                else:
                    print(f'  NOT reliable - probe returned commodities: {sorted(values)}')
            else:
                print('  Probe returned zero records - treating as unsupported.')
        except Exception as exc:  # noqa: BLE001
            print(f'  Probe failed: {redact(exc, api_key)} - treating as unsupported.')
    else:
        print('  No commodity field detected - cannot use server filtering.')
    print(f'  => strategy: '
          f'{"server-side filters[commodity]" if server_filter else "full fetch + local filtering"}')
    time.sleep(REQUEST_DELAY_S)

    # ---- Fetch per commodity ----------------------------------------------
    print(f'\n[3/4] Fetching data for {len(selected)} commodities...')
    summary = []           # (crop, n_records, status)
    all_rows = []          # normalized rows
    full_cache = None      # lazily built only in local-filtering mode

    def matches(crop_synonyms, commodity_value):
        cv = str(commodity_value).lower()
        return any(s in cv for s in crop_synonyms)

    for crop, synonyms in selected.items():
        print(f'\n  - {crop}')
        crop_rows = []
        try:
            if server_filter:
                crop_seen = set()
                for syn in synonyms:
                    raws = fetch_variant_tail(
                        resource_id, api_key, syn,
                        label=f'{crop}:{syn}',
                    )
                    # Strict validation: the API filter does token/partial
                    # matching, so reject any record whose actual commodity
                    # does not normalize to exactly the queried synonym.
                    syn_norm = normalize_commodity(syn)
                    rejected = 0
                    for raw in raws:
                        if commodity_src and \
                                normalize_commodity(raw.get(commodity_src, '')) != syn_norm:
                            rejected += 1
                            continue
                        key = tuple(sorted((k, str(v)) for k, v in raw.items()))
                        if key in crop_seen:
                            continue
                        crop_seen.add(key)
                        crop_rows.append(normalize_record(raw, mapping))
                    if rejected:
                        print(f'    [{crop}:{syn}] rejected {rejected} '
                              f'non-exact rows from partial-match filter')
                    time.sleep(REQUEST_DELAY_S)
                status = 'OK' if crop_rows else 'NO DATA'
            else:
                if full_cache is None:
                    print('    building full dataset cache (one-time)...')
                    full_cache = paginate(
                        resource_id, api_key, label='ALL COMMODITIES'
                    )
                    print(f'    cache size: {len(full_cache)}')
                crop_rows = [
                    normalize_record(raw, mapping)
                    for raw in full_cache
                    if matches(synonyms, raw.get(commodity_src, ''))
                ]
                status = 'OK' if crop_rows else 'NO DATA'
        except Exception as exc:  # noqa: BLE001
            print(f'    FAILED after retries: {redact(exc, api_key)}')
            status = 'FAILED'

        kept = 0
        for row in crop_rows:
            all_rows.append(row)
            kept += 1
        summary.append((crop, kept, status))

    # ---- Save + summarize ---------------------------------------------------
    print('\n[4/4] Saving and summarizing...')
    new_df = pd.DataFrame(all_rows, columns=TARGET_COLUMNS)
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

    if args.append and os.path.exists(OUTPUT_PATH):
        existing = pd.read_csv(OUTPUT_PATH)
        existing.columns = [c.strip() for c in existing.columns]
        combined = pd.concat([existing, new_df], ignore_index=True)
        before = len(combined)
        combined = combined.drop_duplicates()
        print(f'Appended {len(new_df):,} new rows: '
              f'{before:,} -> {len(combined):,} after dedupe')
        df = combined
    else:
        df = new_df

    df.to_csv(OUTPUT_PATH, index=False)

    print('\n' + '=' * 64)
    print(f'{"Commodity":<16}| {"Records":>7} | Status')
    print('-' * 64)
    for crop, n, status in summary:
        print(f'{crop:<16}| {n:>7} | {status}')
    print('-' * 64)
    print(f'TOTAL RECORDS SAVED: {len(df)}')
    print(f'Saved to: {OUTPUT_PATH}')
    print('=' * 64)


if __name__ == '__main__':
    main()
