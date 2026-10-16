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
