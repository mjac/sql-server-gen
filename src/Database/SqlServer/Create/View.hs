module Database.SqlServer.Create.View
       (
         View
       , withCheckOption
       ) where

import Database.SqlServer.Create.Identifier
import Database.SqlServer.Create.Entity
import Database.SqlServer.Create.Table

import Test.QuickCheck
import Text.PrettyPrint hiding (render)

data View = View
  {
    viewName :: RegularIdentifier
  , tables :: [Table]
  , withCheckOption :: Bool
  , encryption :: Bool
  , viewMetadata :: Bool
  }

unionSelectStatement :: View -> Doc
unionSelectStatement v = vcat $ punctuate (text " UNION ALL") (map selectN tabs)
  where
    tabs = tables v

selectN :: Table -> Doc
selectN t = text "SELECT" <+>
            hcat (punctuate comma cols) <+>
            text "FROM" <+> renderName t
  where
    cols = map (renderRegularIdentifier . columnName) $ unpack (columns t)

renderPrerequisites :: View -> Doc
renderPrerequisites = vcat . map render . tables

renderWithOptions :: View -> Doc
renderWithOptions v
  | noneSet = empty
  | otherwise = text "WITH" <+>
                hcat (punctuate comma (filter (not . (== empty)) [enc, vm]))
  where
    noneSet = not (encryption v) && not (viewMetadata v)
    enc = if encryption v then text "ENCRYPTION" else empty
    vm = if viewMetadata v then text "VIEW_METADATA" else empty

instance Arbitrary View where
  arbitrary = do
    n <- arbitrary
    t <- arbitrary
    co <- arbitrary
    e <- arbitrary
    vm <- arbitrary
    return (View n [t] co e vm)

instance Entity View where
  name = viewName
  render v = renderPrerequisites v $+$
            text "CREATE VIEW" <+> renderName v $+$
            renderWithOptions v $+$
            text "AS" $+$
            unionSelectStatement v $+$
            (if withCheckOption v then text "WITH CHECK OPTION" else empty) $+$
            text "GO\n"

instance Show View where
  show = show . render
