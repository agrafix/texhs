----------------------------------------------------------------------
-- |
-- Module      :  Text.TeX.Lexer.TokenParser
-- Copyright   :  2015-2016 Mathias Schenner,
--                2015-2016 Language Science Press.
-- License     :  GPL-3
--
-- Maintainer  :  mathias.schenner@langsci-press.org
-- Stability   :  experimental
-- Portability :  GHC
--
-- Parsers for TeX tokens.
----------------------------------------------------------------------

module Text.TeX.Lexer.TokenParser
       ( runLexer
       , runLexerIO
       , texLexer
       , defaultLexerState
       ) where

import Text.TeX.Lexer.TokenParser.Core (runLexer, runLexerIO)
import Text.TeX.Lexer.TokenParser.Execution (texLexer)
import Text.TeX.Lexer.TokenParser.State (defaultLexerState)
