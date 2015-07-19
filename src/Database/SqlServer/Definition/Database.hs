{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TemplateHaskell #-}
module Database.SqlServer.Definition.Database where

import Database.SqlServer.Definition.Identifier (RegularIdentifier,renderRegularIdentifier)
import Database.SqlServer.Definition.Table (Table)
import Database.SqlServer.Definition.Sequence (Sequence)
import Database.SqlServer.Definition.Procedure (Procedure)
import Database.SqlServer.Definition.Queue (Queue)
import Database.SqlServer.Definition.Certificate (Certificate)
import Database.SqlServer.Definition.Login (Login)
import Database.SqlServer.Definition.User (User,Role)
import Database.SqlServer.Definition.FullTextCatalog (FullTextCatalog)
import Database.SqlServer.Definition.FullTextStopList (FullTextStopList)
import Database.SqlServer.Definition.Function (Function)
import Database.SqlServer.Definition.Credential (Credential)
import Database.SqlServer.Definition.MessageType (MessageType)
import Database.SqlServer.Definition.Entity

import Test.QuickCheck
import Test.QuickCheck.Gen
import Test.QuickCheck.Random

import Text.PrettyPrint
import Data.DeriveTH

data MasterKey = MasterKey

derive makeArbitrary ''MasterKey

instance Entity MasterKey where
  toDoc MasterKey = text "CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'weKKjwehg252t!!'" $+$
                    text "GO"
                        
data DatabaseDefinition = DatabaseDefinition
                          {
                            databaseName :: RegularIdentifier
                          , tables :: [Table]
                          , sequences :: [Sequence]
                          , procedures :: [Procedure]
                          , functions :: [Function]
                          , queues :: [Queue]
                          , certificates :: [Certificate]
                          , users :: [User]
                          , roles :: [Role]
                          , logins :: [Login]
                          , fullTextCatalogs :: [FullTextCatalog]
                          , fullTextStopLists :: [FullTextStopList]
                          , credentials :: [Credential]
                          , messages :: [MessageType]
                          , masterKey :: MasterKey
                          }

renderNamedEntities :: Entity a => [a] -> Doc
renderNamedEntities xs = vcat (map toDoc xs)

renderDatabaseDefinition :: DatabaseDefinition -> Doc
renderDatabaseDefinition  dd = text "USE master" $+$
                               text "GO" $+$
                               text "CREATE DATABASE" <+> dbName $+$
                               text "GO" $+$
                               text "USE" <+> dbName $+$
                               toDoc (masterKey dd) $+$
                               renderNamedEntities (tables dd) $+$
                               renderNamedEntities (sequences dd) $+$
                               renderNamedEntities (procedures dd) $+$
                               renderNamedEntities (functions dd) $+$
                               renderNamedEntities (queues dd) $+$
                               renderNamedEntities (certificates dd) $+$
                               renderNamedEntities (users dd) $+$
                               renderNamedEntities (roles dd) $+$
                               renderNamedEntities (logins dd) $+$
                               renderNamedEntities (fullTextCatalogs dd) $+$
                               renderNamedEntities (fullTextStopLists dd) $+$
                               renderNamedEntities (credentials dd) $+$
                               renderNamedEntities (messages dd) $+$ 
                               text "GO"
  where
    dbName = renderRegularIdentifier (databaseName dd)

derive makeArbitrary ''DatabaseDefinition

dumpExamples :: Int -> FilePath -> IO ()
dumpExamples m p = do
  x <- generate (sequence [resize n (arbitrary :: Gen DatabaseDefinition) | n <- [0..m] ])
  writeFile p (unlines $ map show x)

instance Show DatabaseDefinition where
  show = render . renderDatabaseDefinition

seededDatabase :: Int -> Int -> DatabaseDefinition
seededDatabase seed = unGen arbitrary (mkQCGen seed) 