{-# LANGUAGE MultiParamTypeClasses, FlexibleContexts,
             TypeSynonymInstances, FlexibleInstances,
             OverloadedStrings #-}

module HsToCoq.Coq.FreeVars (
  -- * Things that contain free variables
  getFreeVars, FreeVars(..),
  -- * Binders
  Binding(..), binding',
  -- * Converting binders to things that contain free variables
  NoBinding(..),
  -- * Utility methods
  topoSortEnvironment,
  -- * Fragments that contain name(s) to bind, but which aren't themselves
  -- 'Binders'
  Names(..),
  -- * Default type class method definitions
  bindingTelescope, foldableFreeVars
  ) where

import Prelude hiding (Num)

import Data.Semigroup ((<>))
import Data.Foldable
import HsToCoq.Util.Containers
import Control.Monad.Variables

import Data.List.NonEmpty (NonEmpty(), (<|))
import Data.Set (Set)
import qualified Data.Set as S
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M

import HsToCoq.Coq.Gallina
import HsToCoq.ConvertHaskell.InfixNames

----------------------------------------------------------------------------------------------------

class Names t where
  names :: t -> Set Ident

instance Names FixBody where
  names (FixBody f _ _ _ _) = S.singleton f

instance Names CofixBody where
  names (CofixBody f _ _ _) = S.singleton f

instance Names IndBody where
  names (IndBody tyName _ _ cons) =
    S.insert tyName $ S.fromList [conName | (conName, _, _) <- cons]

----------------------------------------------------------------------------------------------------

class Binding b where
  binding :: (MonadVariables Ident d m, Monoid d) => (Ident -> d) -> b -> m a -> m a

binding' :: (Binding b, MonadVariables Ident d m, Monoid d) => b -> m a -> m a
binding' = binding $ const mempty

instance Binding Ident where
  binding f x = bind x (f x)

instance Binding Name where
  binding f (Ident x)      = binding f x
  binding _ UnderscoreName = id

instance Binding Binder where
  binding f (Inferred ex x) getFVs = do
    freeVars ex
    binding f x getFVs
  binding f (Typed gen ex xs ty) getFVs = do
    freeVars gen
    freeVars ex
    freeVars ty
    foldr (binding f) getFVs xs
  binding f (BindLet x oty val) getFVs = do
    freeVars oty
    freeVars val
    binding f x getFVs
  binding _ (Generalized ex ty) getFVs = do
    freeVars ex
    freeVars ty
    getFVs

instance Binding Annotation where
  binding f (Annotation x) = binding f x

instance Binding MatchItem where
  binding f (MatchItem t oas oin) = (freeVars t *>) . binding f oas . binding f oin

instance Binding MultPattern where
  binding f (MultPattern pats) = binding f pats

-- Note [Bound variables in patterns]
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- We cannot quite capture /all/ the free variables that occur in patterns.  The
-- ambiguous case is that a zero-ary constructor used unqualified looks exactly
-- like a variable used as a binder in a pattern.  So what do we do?  The answer
-- is that we treat is as a binder.  This is the right behavior: Coq has the
-- same problem, and it manages because it treats all unknown variables as
-- binders, as otherwise they'd be in scope.  What's more, treating all
-- variables as binders gives the right result in the body: even if it /wasn't/
-- a binder, it must have been bound already, so at least it will be bound in
-- the body!
--
-- We don't have to worry about module-qualified names, as they must be
-- references to existing terms; and we don't have to worry about constructors
-- /applied/ to arguments, as binders cannot be so applied.

-- See Note [Bound variables in patterns]
instance Binding Pattern where
  binding f (ArgsPat con xs) =
    (freeVars con *>) . binding f xs
  
  binding f (ExplicitArgsPat con xs) =
    (freeVars con *>) . binding f xs
  
  binding f (InfixPat l op r) =
    (occurrence op *>) . binding f [l,r]
  
  binding f (AsPat pat x) =
    binding f pat . binding f x
    -- This correctly binds @x@ as the innermost binding f
  
  binding f (InScopePat pat _scope) =
    binding f pat
    -- The scope is a different sort of identifier, not a term-level variable.

  binding f (QualidPat (Bare x)) =
    binding f x
    -- See [Note Bound variables in patterns]
  
  binding _ (QualidPat qid@(Qualified _ _)) =
    (freeVars qid *>)
  
  binding _ UnderscorePat =
    id
  
  binding _ (NumPat _num) =
    id
  
  binding _ (StringPat _str) =
    id
  
  binding f (OrPats ors) =
    binding f ors
    -- We don't check that all the or-patterns bind the same variables

instance Binding OrPattern where
  binding f (OrPattern pats) = binding f pats

-- An @in@-annotation, as found in 'LetTickDep' or 'MatchItem'.
instance Binding (Qualid, [Pattern]) where
  binding f (con, pats) = (freeVars con *>) . binding f pats

instance Binding Sentence where
  binding f (AssumptionSentence assum)     = binding f assum
  binding f (DefinitionSentence def)       = binding f def
  binding f (InductiveSentence  ind)       = binding f ind
  binding f (FixpointSentence   fix)       = binding f fix
  binding f (AssertionSentence  assert pf) = binding f assert . (freeVars pf *>)
  binding f (ClassSentence      cls)       = binding f cls
  binding f (InstanceSentence   ins)       = binding f ins
  binding f (NotationSentence   not)       = binding f not
  binding _ (CommentSentence    com)       = (freeVars com *>)

instance Binding Assumption where
  binding f (Assumption kwd assumptions) =
    (freeVars kwd *>) . binding f assumptions
    -- The @kwd@ part is pro forma – there are no free variables there

instance Binding Assums where
  binding f (UnparenthesizedAssums xs ty) =
    (freeVars ty *>) . binding f xs
  binding f (ParenthesizedAssums xsTys) = \body ->
    foldr (\(xs,ty) -> (freeVars ty *>) . binding f xs) body xsTys

instance Binding Definition where
  binding f (DefinitionDef isLocal x args oty def) =
    (freeVars isLocal *>)               . -- Pro forma – there are none
    binding f args                        .
      (freeVars oty *> freeVars def *>) .
      binding f x
  
  binding f (LetDef x args oty def) =
    binding f args                        .
      (freeVars oty *> freeVars def *>) .
      binding f x

instance Binding Inductive where
  binding f (Inductive   ibs nots) = binding f (foldMap names ibs) . (freeVars ibs *> freeVars (NoBinding nots) *>)
  binding f (CoInductive cbs nots) = binding f (foldMap names cbs) . (freeVars cbs *> freeVars (NoBinding nots) *>)
  -- The notation bindings here can only rebind existing reserved names, so we
  -- fake out @binding' nots@ to get the free variables.

instance Binding Fixpoint where
  binding f (Fixpoint   fbs nots) = binding f (foldMap names fbs) . (freeVars fbs *> freeVars (NoBinding nots) *>)
  binding f (CoFixpoint cbs nots) = binding f (foldMap names cbs) . (freeVars cbs *> freeVars (NoBinding nots) *>)
  -- The notation bindings here can only rebind existing reserved names, so we
  -- fake out @binding' nots@ to get the free variables.

instance Binding Assertion where
  binding f (Assertion kwd name args ty) =
    (freeVars kwd *> binding f args (freeVars ty) *>) .
    binding f name
    -- The @kwd@ part is pro forma – there are no free variables there

instance Binding ClassDefinition where
  binding f (ClassDefinition cl params osort fields) =
    (freeVars (NoBinding params) *> freeVars osort *>) .
    binding f cl .
    flip (foldr (\(field,ty) -> (binding f params (freeVars ty) *>) . binding f field)) fields

instance Binding InstanceDefinition where
  binding f (InstanceDefinition inst params cl defns mpf) =
    binding f params .
    (freeVars cl *> freeVars (map snd defns) *> freeVars mpf *>) .
    binding f inst

instance Binding Notation where
  binding f (ReservedNotationIdent x) = binding f x
    -- We treat reserved single-identifier notations as bound variables
  binding f (NotationBinding nb) = binding f nb
  binding f (InfixDefinition op defn oassoc level) =
    (freeVars defn *> freeVars oassoc *> freeVars level *>) . binding f op
    -- We treat infix operators as bound variables

instance Binding NotationBinding where
  binding f (NotationIdentBinding x def) = (freeVars def *>) . binding f x

-- TODO Not all sequences of bindings should be telescopes!
bindingTelescope :: (Binding b, MonadVariables Ident d m, Monoid d, Foldable f)
                 => (Ident -> d) -> f b -> m a -> m a
bindingTelescope = flip . foldr . binding

instance Binding (Set Ident) where
  binding = (bindAll .) . M.fromSet

instance Binding b => Binding (Maybe b) where
  binding = bindingTelescope

instance Binding b => Binding [b] where
  binding = bindingTelescope

instance Binding b => Binding (NonEmpty b) where
  binding = bindingTelescope

----------------------------------------------------------------------------------------------------

getFreeVars :: FreeVars t => t -> Set Ident
getFreeVars = execVariables . (freeVars :: FreeVars t => t -> Variables Ident () ())

class FreeVars t where
  freeVars :: (MonadVariables Ident d m, Monoid d) => t -> m ()

instance FreeVars Term where
  freeVars (Forall xs t) =
    binding' xs $ freeVars t
  
  freeVars (Fun xs t) =
    binding' xs $ freeVars t
  
  freeVars (Fix fbs) =
    freeVars fbs
  
  freeVars (Cofix cbs) =
    freeVars cbs

  freeVars (Let x args oty val body) = do
    binding' args $ freeVars oty *> freeVars val
    binding' x    $ freeVars body
  
  freeVars (LetFix fb body) = do
    freeVars fb
    binding' (names fb) $ freeVars body

  freeVars (LetCofix cb body) = do
    freeVars cb
    binding' (names cb) $ freeVars body

  freeVars (LetTuple xs oret val body) = do
    freeVars oret *> freeVars val
    binding' xs $ freeVars body
  
  freeVars (LetTick pat def body) = do
    freeVars def
    binding' pat $ freeVars body
  
  freeVars (LetTickDep pat oin def ret body) = do
    freeVars def
    binding' oin $ freeVars ret
    binding' pat $ freeVars body

  freeVars (If c oret t f) =
    freeVars c *> freeVars oret *> freeVars [t,f]

  freeVars (HasType tm ty) =
    freeVars [tm, ty]

  freeVars (CheckType tm ty) =
    freeVars [tm, ty]

  freeVars (ToSupportType tm) =
    freeVars tm

  freeVars (Arrow ty1 ty2) =
    freeVars [ty1, ty2]

  freeVars (App f xs) =
    freeVars f *> freeVars xs

  freeVars (ExplicitApp qid xs) =
    freeVars qid *> freeVars xs

  freeVars (Infix l op r) =
    freeVars l *> occurrence op *> freeVars r
  
  freeVars (InScope t _scope) =
    freeVars t
    -- The scope is a different sort of identifier, not a term-level variable.

  freeVars (Match items oret eqns) = do
    binding' items $ freeVars oret
    freeVars eqns

  freeVars (Qualid qid) =
    freeVars qid

  freeVars (Sort sort) =
    freeVars sort -- Pro forma – there are none.

  freeVars (Num _num) =
    pure () -- There are none.

  freeVars (PolyNum _num) =
    pure () -- There are none.

  freeVars (String _str) =
    pure () -- There are none.

  freeVars Underscore =
    pure ()

  freeVars (Parens t) =
    freeVars t

  freeVars MissingValue =
    pure ()

instance FreeVars Arg where
  freeVars (PosArg      t) = freeVars t
  freeVars (NamedArg _x t) = freeVars t
    -- The name here is the name of a function parameter; it's not an occurrence
    -- of a Gallina-level variable.

instance FreeVars Generalizability where
  freeVars Ungeneralizable = pure ()
  freeVars Generalizable   = pure ()

instance FreeVars Explicitness where
  freeVars Explicit = pure ()
  freeVars Implicit = pure ()

instance FreeVars Qualid where
  freeVars = occurrence . toIdent where
    toIdent (Bare x)          = x
    toIdent (Qualified mod x) = toIdent mod <> "." <> x

instance FreeVars Sort where
  freeVars Prop = pure ()
  freeVars Set  = pure ()
  freeVars Type = pure ()

instance FreeVars FixBodies where
  freeVars (FixOne fb) =
    freeVars fb
  freeVars (FixMany fb' fbs' x) =
    let fbs = fb' <| fbs'
    in binding' (x `S.insert` foldMap names fbs) $ freeVars fbs

instance FreeVars CofixBodies where
  freeVars (CofixOne cb) =
    freeVars cb
  freeVars (CofixMany cb' cbs' x) =
    let cbs = cb' <| cbs'
    in binding' (x `S.insert` foldMap names cbs) $ freeVars cbs

instance FreeVars FixBody where
  freeVars (FixBody f args annot oty def) =
    binding' f . binding' args . binding' annot $ do
      freeVars oty
      freeVars def

instance FreeVars CofixBody where
  freeVars (CofixBody f args oty def) =
    binding' f . binding' args $ do
      freeVars oty
      freeVars def

instance FreeVars DepRetType where
  freeVars (DepRetType oas ret) = binding' oas $ freeVars ret

instance FreeVars ReturnType where
  freeVars (ReturnType ty) = freeVars ty

instance FreeVars Equation where
  freeVars (Equation mpats body) = binding' mpats $ freeVars body

instance FreeVars Comment where
  freeVars (Comment _) = pure ()

instance FreeVars AssumptionKeyword where
  freeVars Axiom      = pure ()
  freeVars Axioms     = pure ()
  freeVars Conjecture = pure ()
  freeVars Parameter  = pure ()
  freeVars Parameters = pure ()
  freeVars Variable   = pure ()
  freeVars Variables  = pure ()
  freeVars Hypothesis = pure ()
  freeVars Hypotheses = pure ()

instance FreeVars Locality where
  freeVars Global = pure ()
  freeVars Local  = pure ()

instance FreeVars IndBody where
  freeVars (IndBody tyName params indicesUniverse cons) =
    binding' params $ do
      freeVars indicesUniverse
      binding' tyName $ sequence_ [binding' args $ freeVars oty | (_,args,oty) <- cons]

instance FreeVars AssertionKeyword where
  freeVars Theorem     = pure ()
  freeVars Lemma       = pure ()
  freeVars Remark      = pure ()
  freeVars Fact        = pure ()
  freeVars Corollary   = pure ()
  freeVars Proposition = pure ()
  freeVars Definition  = pure ()
  freeVars Example     = pure ()

instance FreeVars Proof where
  -- We don't model proofs.
  freeVars (ProofQed      _tactics) = pure ()
  freeVars (ProofDefined  _tactics) = pure ()
  freeVars (ProofAdmitted _tactics) = pure ()

instance FreeVars Associativity where
  freeVars LeftAssociativity  = pure ()
  freeVars RightAssociativity = pure ()
  freeVars NoAssociativity    = pure ()

instance FreeVars Level where
  freeVars (Level _) = pure ()

foldableFreeVars :: (FreeVars t, MonadVariables Ident d m, Monoid d, Foldable f) => f t -> m ()
foldableFreeVars = traverse_ freeVars

instance FreeVars t => FreeVars (Maybe t) where
  freeVars = foldableFreeVars

instance FreeVars t => FreeVars [t] where
  freeVars = foldableFreeVars

instance FreeVars t => FreeVars (NonEmpty t) where
  freeVars = foldableFreeVars

----------------------------------------------------------------------------------------------------

newtype NoBinding b = NoBinding { getNoBinding :: b } deriving (Eq, Ord, Show, Read)

instance Binding b => FreeVars (NoBinding b) where
  freeVars (NoBinding b) = binding' b $ pure ()

----------------------------------------------------------------------------------------------------

-- The order is correct – later identifiers refer only to previous ones – since
-- 'stronglyConnComp'' returns its outputs in topologically sorted order.
topoSortEnvironment :: FreeVars t => Map Ident t -> [NonEmpty Ident]
topoSortEnvironment = stronglyConnComp' . M.toList
                    . fmap (fmap canonicalName . S.toList . getFreeVars)
