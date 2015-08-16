module Database.SqlServer.Definition.Table
       (
         Table
       , Column
       , columnName
       , columnCount
       , columns
       , unpack
       ) where

import Database.SqlServer.Definition.Identifier (RegularIdentifier, renderRegularIdentifier)
import Database.SqlServer.Definition.DataType (
  Type,
  renderDataType,
  collation,
  renderSparse,
  storageOptions,
  renderNullConstraint,
  nullOptions,
  storageSize,
  renderRowGuidConstraint,
  rowGuidOptions,
  isTimestamp,
  isTypeForIndex
  )
  
import Database.SqlServer.Definition.Collation (renderCollation)
import Database.SqlServer.Definition.Entity

import Test.QuickCheck
import Text.PrettyPrint hiding (render)
import Data.Maybe (isJust)
import Control.Monad

data Column = Column
  {
    columnName :: RegularIdentifier
  , dataType   :: Type
  }

instance Arbitrary Column where
  arbitrary = do
    n <- arbitrary
    t <- arbitrary
    return $ Column n t    

newtype Columns = Columns { unpack :: [Column] }

data IndexType = PrimaryKey | Unique

instance Arbitrary IndexType where
  arbitrary = elements [PrimaryKey, Unique]

data SortOrder = Ascending | Descending

instance Arbitrary SortOrder where
  arbitrary = elements [Ascending, Descending]

newtype FillFactor = FillFactor Int

instance Arbitrary FillFactor where
  arbitrary = liftM FillFactor $ choose (1,100)

data IndexOption = IndexOption
  {
    padIndex :: Maybe Bool
  , ignoreDupKey :: Maybe Bool
  , statisticsNoRecompute :: Maybe Bool
  , allowRowLocks :: Maybe Bool
  , allowPageLocks :: Maybe Bool
  , indexFillFactor :: Maybe FillFactor
  }  

instance Arbitrary IndexOption where
  arbitrary = IndexOption <$>
    arbitrary <*>
    arbitrary <*>
    arbitrary <*>
    arbitrary <*>
    arbitrary <*>
    arbitrary

renderIndexType :: IndexType -> Doc
renderIndexType PrimaryKey = text "PRIMARY KEY"
renderIndexType Unique = text "UNIQUE"

renderSortOrder :: SortOrder -> Doc
renderSortOrder Ascending = text "ASC"
renderSortOrder Descending = text "DESC"

renderOption :: Bool -> Doc
renderOption False = text "OFF"
renderOption True = text "ON"

renderIndexOption :: IndexOption -> Doc
renderIndexOption i
  | null vs   = empty
  | otherwise = text "WITH" <+> parens (vcat (punctuate comma vs))
  where
    vs = filter (/= empty) xs
    xs =
      [
        maybe empty (\x -> text "PAD_INDEX = " <+> renderOption x) (padIndex i)
      , maybe empty (\x -> text "IGNORE_DUP_KEY = " <+> renderOption x) (ignoreDupKey i)
      , maybe empty (\x -> text "STATISTICS_NORECOMPUTE = " <+> renderOption x) (statisticsNoRecompute i)
      , maybe empty (\x -> text "ALLOW_ROW_LOCKS = " <+> renderOption x) (allowRowLocks i)
      , maybe empty (\x -> text "ALLOW_PAGE_LOCKS = " <+> renderOption x) (allowPageLocks i)
      , maybe empty (\(FillFactor x) -> text "FILLFACTOR = " <+> int x) (indexFillFactor i)
      ]

atLeastOneOptionSet :: IndexOption -> Bool
atLeastOneOptionSet i = isJust (padIndex i) ||
                        isJust (ignoreDupKey i) ||
                        isJust (statisticsNoRecompute i) ||
                        isJust (allowRowLocks i) ||
                        isJust (allowPageLocks i) ||
                        isJust (indexFillFactor i)

data TableConstraint = TableConstraint
  {
    constraintName :: RegularIdentifier
  , indexType :: IndexType
  , column :: RegularIdentifier
  , sortOrder :: Maybe SortOrder
  , indexOption :: Maybe IndexOption
  }

generateTableConstraint :: Columns -> Gen (Maybe TableConstraint)
generateTableConstraint (Columns cd) = case filter (isTypeForIndex . dataType) cd of
  [] -> return Nothing
  xs -> do
    n <- arbitrary
    c <- columnName <$> elements xs
    it <- arbitrary
    so <- arbitrary
    io <- arbitrary `suchThatMaybe` atLeastOneOptionSet
    frequency
      [
        (10, return Nothing),
        (90, return $ Just TableConstraint
           {
             constraintName = n
           , indexType = it
           , column = c
           , sortOrder = so
           , indexOption = io
           })
      ]
  

renderTableConstraint :: TableConstraint -> Doc
renderTableConstraint t = text "CONSTRAINT" <+>
                          renderRegularIdentifier (constraintName t) <+>
                          renderIndexType (indexType t) <+>
                          parens (
                            renderRegularIdentifier (column t) <+>
                            maybe empty renderSortOrder (sortOrder t)) <+>
                          maybe empty renderIndexOption (indexOption t)

data Table = Table
  {
    tableName    :: RegularIdentifier
  , columns :: Columns
  , tableConstraint :: Maybe TableConstraint
  }

columnCount :: Table -> Int
columnCount t = case columns t of
                  Columns xs -> length xs

columnConstraintsSatisfied :: [Column] -> Bool
columnConstraintsSatisfied xs = length (filter columnIsTimestamp xs) <= 1 && 
                                totalColumnSizeBytes <= 8060 &&
                                length (filter (rowGuidOptions . dataType) xs) <= 1 
  where
    totalColumnSizeBits = (length xs * 8) + 32 + sum (map (storageSize . dataType) xs)
    totalColumnSizeBytes = totalColumnSizeBits `div` 8 + (if totalColumnSizeBits `rem` 8 /= 0 then 8 else 0)
    columnIsTimestamp = isTimestamp . dataType
    
instance Arbitrary Table where
  arbitrary = do
    cols <- arbitrary 
    nm <- arbitrary
    f <- generateTableConstraint cols
    return $ Table nm cols f

instance Arbitrary Columns where
  arbitrary = do
    cols <- listOf1 arbitrary `suchThat` columnConstraintsSatisfied
    return $ Columns cols

renderColumns :: Columns -> [Doc]
renderColumns (Columns xs) = cols
  where
    cols = map renderColumn xs

renderColumn :: Column -> Doc
renderColumn c = columnName' <+> columnType' <+> collation' <+>
                           sparse <+> nullConstraint <+> rowGuidConstraint
  where
    columnName'       = renderRegularIdentifier (columnName c)
    columnType'       = renderDataType $ dataType c
    collation'        = maybe empty renderCollation (collation (dataType c))
    sparse            = maybe empty renderSparse (storageOptions (dataType c))
    nullConstraint    = maybe empty renderNullConstraint (nullOptions (dataType c))
    rowGuidConstraint = renderRowGuidConstraint (rowGuidOptions (dataType c))

instance Entity Table where
  name = tableName
  render t = text "CREATE TABLE" <+> renderName t $$
            parens (vcat $ punctuate comma (col ++ con)) $+$
            text "GO"
    where
      col = renderColumns (columns t)
      con = maybe [] (\x -> [renderTableConstraint x]) (tableConstraint t)

instance Show Table where
  show = show . render
