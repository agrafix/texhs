----------------------------------------------------------------------
-- |
-- Module      :  Text.TeX.Lexer.Macro
-- Copyright   :  (c) Mathias Schenner 2015,
--                (c) Language Science Press 2015.
-- License     :  GPL-3
--
-- Maintainer  :  mathias.schenner@langsci-press.org
-- Stability   :  experimental
-- Portability :  portable
--
-- Types and utility functions for TeX macros.
----------------------------------------------------------------------

module Text.TeX.Lexer.Macro
  ( -- * Macro types
    Macro
  , MacroKey
  , macroName
  , macroContext
  , macroBody
  , MacroEnv
  , MacroEnvKey
  , MacroEnvDef(..)
  , ArgSpec
  , ArgType(..)
    -- * Macro expansion
  , applyMacro
  ) where

import Text.TeX.Lexer.Token (Token(..))
import Text.TeX.Lexer.Catcode (Catcode)

-------------------- Argument Specification

type ArgSpec = [ArgType]

data ArgType = Mandatory        -- ^ For 'm' args
             | Until            -- ^ For 'u' args
               [Token]
             | UntilCC          -- ^ For 'l' args
               Catcode
             | Delimited        -- ^ For 'r' args
               Token            -- ^ Opening delimiter
               Token            -- ^ Closing delimiter
               (Maybe [Token])  -- ^ Default value
             | OptionalGroup    -- ^ For 'o' and 'd' args
               Token            -- ^ Opening delimiter
               Token            -- ^ Closing delimiter
               (Maybe [Token])  -- ^ Default value
             | OptionalGroupCC  -- ^ For 'g' args
               Catcode          -- ^ Opening delimiter
               Catcode          -- ^ Closing delimiter
               (Maybe [Token])  -- ^ Default value
             | OptionalToken    -- ^ For 's' and 't' args
               Token
             | LiteralToken     -- ^ Literal token
               Token            -- (for translating from def-style macros)
             deriving (Eq, Show)


-------------------- Macro types

-- Fields: @(name, active)@.
-- | Key for macro lookup.
type MacroKey = (String, Bool)

-- For now we use a simple type synonym rather than a full data type
-- so we can use @lookup@ in @[Macro]@ without any unwrapping.
-- Fields: @((name, active), (context, body))@.
-- | A Macro maps a name (and a flag for active characters) to a macro
-- context and a macro body.
type Macro = (MacroKey, (ArgSpec, [Token]))

-- | Extract name of a macro.
macroName :: Macro -> String
macroName = fst . fst

-- | Extract context from a macro.
macroContext :: Macro -> ArgSpec
macroContext = fst . snd

-- | Extract body from a macro.
macroBody :: Macro -> [Token]
macroBody = snd . snd

-------------------- MacroEnv types

-- | Key for environment lookup.
type MacroEnvKey = [Token]

-- | Definition of an environment.
data MacroEnvDef = MacroEnvDef
                   { macroEnvContext :: ArgSpec
                   , macroEnvStart :: [Token]
                   , macroEnvEnd :: [Token]
                   } deriving (Eq, Show)

-- | An environment maps a name to a macro context,
-- a start code (before) and an end code (after).
type MacroEnv = (MacroEnvKey, MacroEnvDef)


-------------------- Macro expansion

-- | Substitute variables in macro body.
--
-- Given a macro definition body and a list of actual arguments,
-- substitute the parameter tokens in the macro body by the actual arguments.
applyMacro :: [Token] -> [[Token]] -> [Token]
applyMacro ((Param i n):ts) args = if n == 1
                                   then (args !! (i-1)) ++ applyMacro ts args
                                   else (Param i (n-1)) : applyMacro ts args
applyMacro (tok@(TeXChar _ _):ts) args = tok : applyMacro ts args
applyMacro (tok@(CtrlSeq _ _):ts) args = tok : applyMacro ts args
applyMacro [] _ = []
