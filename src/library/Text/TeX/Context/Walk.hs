{-# LANGUAGE GeneralizedNewtypeDeriving #-}
----------------------------------------------------------------------
-- |
-- Module      :  Text.TeX.Context.Walk
-- Copyright   :  (c) Mathias Schenner 2015,
--                (c) Language Science Press 2015.
-- License     :  GPL-3
--
-- Maintainer  :  mathias.schenner@langsci-press.org
-- Stability   :  experimental
-- Portability :  portable
--
-- Parser type for walking TeX contexts
----------------------------------------------------------------------

module Text.TeX.Context.Walk
  ( -- * Types
    Parser
  , runParser
    -- * Basic combinators
  , choice
  , list
    -- * Command parsers
    -- ** Specific command
  , cmd
  , inCmd
  , cmdDown
    -- * Group parsers
    -- ** Specific group
  , grp
  , inGrp
  , grpDown
    -- ** Any group
  , optNested
  , goDown
  , goUp
  , safeUp
    -- * Lift TeX Context traversals
  , step
  , stepRes
    -- * Low-level parsers
  , satisfy
  , peek
  , item
  , eof
  , eog
  , dropParents
  ) where

import Control.Applicative
import Control.Monad
import qualified Control.Monad.Trans.Except as E
import qualified Control.Monad.Trans.State as S

import Text.TeX.Parser.Types
import Text.TeX.Context.Types


---------- Types

-- | A parser for walking a TeX AST.
newtype Parser a = Parser
    { parser :: S.StateT TeXContext (E.Except [TeXDocError]) a }
  deriving (Functor, Applicative, Monad, Alternative, MonadPlus)

-- | Run a parser on a TeX AST.
runParser :: Parser a -> TeX -> ThrowsError a
runParser p xs = E.runExcept (S.evalStateT (parser p) (pureTeXContext xs))

liftP :: (TeXContext -> E.Except [TeXDocError] (a, TeXContext)) -> Parser a
liftP = Parser . S.StateT

state :: (TeXContext -> (a, TeXContext)) -> Parser a
state = Parser . S.state

put :: TeXContext -> Parser ()
put = Parser . S.put

get :: Parser TeXContext
get = Parser S.get

throwE :: TeXDocError -> Parser a
throwE e = liftP (const (E.throwE [e]))


---------- Low-level parsers

-- | Return the next 'TeXAtom' if it satisfies the provided predicate.
satisfy :: (TeXAtom -> Bool) -> Parser TeXAtom
satisfy p = peek p *> item

-- | Peek at head of focus.
--
-- Like 'satisfy' but does not consume the matched 'TeXAtom'.
peek :: (TeXAtom -> Bool) -> Parser ()
peek = step . testHeadErr

-- | Return the next 'TeXAtom'.
item :: Parser TeXAtom
item = stepRes unconsFocus

-- | Succeed if context is empty.
eof :: Parser ()
eof = step testEof

-- | Succeed if focus is empty (i.e. if we hit an end of group).
eog :: Parser ()
eog = step testEog

-- | Restrict context to focus.
dropParents :: Parser ()
dropParents = step resetParents


---------- Basic combinators

-- | Try parsers from a list until one succeeds.
choice :: [Parser a] -> Parser a
choice = msum

-- | @list bullet p@ parses zero or more occurrences of @p@, each prefixed by @bullet@.
-- Returns a list of values returned by @p@.
--
-- Note: @p@ must not overlap with @bullet@.
list :: Parser a -> Parser b -> Parser [b]
list bullet p = many (bullet *> p)

---------- Command parsers

-- | Parse a specific command.
cmd :: String -> Parser TeXAtom
cmd = satisfy . isCmd

-- | Apply parser to the first mandatory argument of a specific command
-- (all other arguments are dropped).
inCmd :: String -> Parser a -> Parser a
inCmd n p = cmdDown n *> p <* safeUp

-- | Descend into the first mandatory argument of a specific command
-- (all other arguments are dropped).
cmdDown :: String -> Parser ()
cmdDown n = step (testHeadErr (isCmd n)) *> step intoCmdArg


---------- Group parsers

-- | Parse a specific group.
grp :: String -> Parser TeXAtom
grp = satisfy . isGrp

-- | Apply parser to specific group body.
inGrp :: String -> Parser a -> Parser a
inGrp n p = grpDown n *> p <* safeUp

-- | Descend into a specific group (ignoring all group arguments).
grpDown :: String -> Parser ()
grpDown n = step (testHeadErr (isGrp n)) *> goDown

-- Apply parser inside a group (any group).
-- The parser must exhaust the group content.
inAnyGroup :: Parser a -> Parser a
inAnyGroup p = goDown *> p <* safeUp

-- | Allow parser to walk into groups (if it fails at the top level).
-- If the parser opens a group, it must exhaust its content.
optNested :: Parser a -> Parser a
optNested p = p <|> inAnyGroup (optNested p)

-- | Descend into a group. See 'down'.
goDown :: Parser ()
goDown = step down

-- | Drop focus and climb up one level. See 'up'.
goUp :: Parser ()
goUp = step up

-- | If focus is empty, climb up one level.
safeUp :: Parser ()
safeUp = eog *> goUp


---------- Lift TeX Context traversals

-- | Execute a 'TeXStep' (no result).
step :: TeXStep -> Parser ()
step dir = get >>= either throwE put . dir

-- | Execute a 'TeXStepRes' (with result).
stepRes :: TeXStepRes a -> Parser a
stepRes dir = get >>= either throwE (state . const) . dir