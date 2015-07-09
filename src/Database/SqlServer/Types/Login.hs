{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TemplateHaskell #-}

module Database.SqlServer.Types.Login where

import Database.SqlServer.Types.Identifiers
import Database.SqlServer.Types.Entity

import Data.DeriveTH
import Test.QuickCheck
import Text.PrettyPrint

data LoginDefinition = LoginDefinition
   {
     loginName :: RegularIdentifier
   , password :: RegularIdentifier
   , mustChange :: Bool 
   }

derive makeArbitrary ''LoginDefinition

renderPassword :: RegularIdentifier -> Doc
renderPassword s = text "WITH PASSWORD = " <>
                   (quotes (renderRegularIdentifier s))

renderMustChange :: Bool -> Doc
renderMustChange False = empty
renderMustChange True = text "MUST_CHANGE" <> comma <> text "CHECK_EXPIRATION=ON"

instance Entity LoginDefinition where
  toDoc a = text "CREATE LOGIN" <+> (renderRegularIdentifier (loginName a)) $+$
            renderPassword (password a)  <+> renderMustChange (mustChange a)
            
 