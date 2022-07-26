-- Can be the from/to of a cell
type Targettable

type Object <: Targettable
type Cell <: Targettable

-- We detect what the target is and create a 1-cell or 2-cell or .. based on that.
constructor MakeCell(Targettable A, Targettable B) -> Cell

-- Which side of the target to attach the cell endpoint at.
-- +-T-+
-- L   R
-- +-B-+
-- predicate ToLeft(Cell)
-- predicate FromLeft(Cell)
-- predicate ToRight(Cell)
-- predicate FromRight(Cell)
-- predicate ToTop(Cell)
-- predicate FromTop(Cell)
-- predicate ToBottom(Cell)
-- predicate FromBottom(Cell)

-- We need very specific, conjunctive predicates as opposed to e.g.
-- `IsFacingRight` or `IsHorizontal` to make the styling work and
-- to optimize constraint solving.
-- TODO: these might break when the target is a cell; can't force cell positioning in this way, probably?
predicate IsLeftHorizontal(Cell)
predicate IsRightHorizontal(Cell)
predicate IsUpVertical(Cell)
predicate IsDownVertical(Cell)
predicate IsRightDownDiagonal(Cell)

predicate IsCurvedLeft(Cell)
predicate IsCurvedRight(Cell)