{-# LANGUAGE FlexibleContexts #-}

module HsToCoq.ConvertHaskell.Declarations.TypeSynonym (SynBody(..), convertSynDecl) where

import Prelude hiding (Num)

import GHC hiding (Name)

import HsToCoq.Coq.Gallina as Coq
import HsToCoq.Coq.FreeVars

import HsToCoq.ConvertHaskell.Monad
import HsToCoq.ConvertHaskell.Variables
import HsToCoq.ConvertHaskell.Type

--------------------------------------------------------------------------------

data SynBody = SynBody Ident [Binder] (Maybe Term) Term
             deriving (Eq, Ord, Read, Show)

instance FreeVars SynBody where
  freeVars (SynBody _name args oty def) = binding' args $ freeVars oty *> freeVars def

convertSynDecl :: ConversionMonad m
               => Located RdrName -> LHsTyVarBndrs RdrName -> LHsType RdrName
               -> m SynBody
convertSynDecl name args def  = SynBody <$> freeVar (unLoc name)
                                        <*> convertLHsTyVarBndrs Coq.Explicit args
                                        <*> pure Nothing
                                        <*> convertLType def