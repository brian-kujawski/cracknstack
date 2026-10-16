class_name BinderLayout
extends RefCounted
## Where a card goes inside a binder. Pages are 9-pocket 3×3 grids numbered
## left to right, top to bottom; each sheet has a front page and a back page.

const POCKETS_PER_PAGE := 9
const COLUMNS := 3
const PAGES_PER_SHEET := 2
## Cards per binder volume: 20 sheets × 2 sides × 9 pockets. A tuning number.
const BINDER_CAPACITY := 360


## Zero-based page index within the binder (front of sheet 1 is page 0).
static func page_of(binder: BinderRange, collector_number: int) -> int:
	return (collector_number - binder.first) / POCKETS_PER_PAGE


## Zero-based pocket index on its page, 0–8, left to right, top to bottom.
static func pocket_of(binder: BinderRange, collector_number: int) -> int:
	return (collector_number - binder.first) % POCKETS_PER_PAGE


## Grid position of a pocket as (column, row), both zero-based.
static func pocket_cell(pocket: int) -> Vector2i:
	return Vector2i(pocket % COLUMNS, pocket / COLUMNS)


static func sheet_of_page(page: int) -> int:
	return page / PAGES_PER_SHEET


static func is_back_of_sheet(page: int) -> bool:
	return page % PAGES_PER_SHEET == 1


static func page_count(binder: BinderRange) -> int:
	return ceili(float(binder.card_capacity()) / POCKETS_PER_PAGE)


## Spreads are what you see with the binder open flat: spread 0 is the
## inside front cover (left) and page 0 (right); after that each spread is
## the back of one sheet (left) and the front of the next (right).
static func spread_count(binder: BinderRange) -> int:
	return page_count(binder) / PAGES_PER_SHEET + 1


## The (left, right) page indices of a spread; -1 where it's a bare cover.
static func spread_pages(binder: BinderRange, spread: int) -> Vector2i:
	var left := spread * PAGES_PER_SHEET - 1
	var right := spread * PAGES_PER_SHEET
	return Vector2i(left, right if right < page_count(binder) else -1)


static func spread_of_page(page: int) -> int:
	return (page + 1) / PAGES_PER_SHEET
