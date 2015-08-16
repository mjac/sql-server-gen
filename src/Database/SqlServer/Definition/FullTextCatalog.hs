module Database.SqlServer.Definition.FullTextCatalog
       (
         FullTextCatalog
       ) where

import Database.SqlServer.Definition.Identifier
import Database.SqlServer.Definition.Entity

import Test.QuickCheck
import Text.PrettyPrint
import Control.Monad

data FullTextCatalog = FullTextCatalog
  {
    catalogName :: RegularIdentifier
  , filegroup :: Maybe RegularIdentifier
  , accentSensitive :: Maybe Bool
  , asDefault :: Bool
  -- TODO ignore users
  }

renderFileGroup :: RegularIdentifier -> Doc
renderFileGroup n = text "ON FILEGROUP" <+> renderRegularIdentifier n

renderOptions :: Bool -> Doc
renderOptions True  = text "WITH ACCENT_SENSITIVITY = ON"
renderOptions False = text "WITH ACCENT_SENSITIVITY = OFF"

instance Arbitrary FullTextCatalog where
  arbitrary = liftM4 FullTextCatalog arbitrary arbitrary arbitrary arbitrary

instance Entity FullTextCatalog where
  name = catalogName
  render ftc = text "CREATE FULLTEXT CATALOG" <+>
              renderName ftc $+$ 
              maybe empty renderFileGroup (filegroup ftc) $+$
              maybe empty renderOptions (accentSensitive ftc) $+$
              if asDefault ftc then text "AS DEFAULT" else empty $+$
              text "GO\n"
