-- Copyright 2019 Google LLC
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE file or at
-- https://developers.google.com/open-source/licenses/bsd

{-# LANGUAGE CPP #-}
-- | This module provides combinators for constructing Haskell patterns.
module GHC.SourceGen.Pat
    ( Pat'
    , wildP
    , asP
    , conP
    , conP_
    , recordConP
    , strictP
    , lazyP
    , sigP
    ) where

import GHC.Hs.Type
import GHC.Hs.Pat hiding (LHsRecField')

import GHC.SourceGen.Name.Internal
import GHC.SourceGen.Pat.Internal
import GHC.SourceGen.Syntax.Internal
import GHC.SourceGen.Type.Internal (patSigType)

-- | A wild pattern (@_@).
wildP :: Pat'
wildP = noExtOrPlaceHolder WildPat

-- | An as-pattern.
--
-- > a@B
-- > =====
-- > asP "a" (var "B")
asP :: RdrNameStr -> Pat' -> Pat'
v `asP` p = noExt AsPat (valueRdrName v) $ builtPat $ parenthesize p

-- | A pattern constructor.
--
-- > A b c
-- > =====
-- > conP "A" [bvar "b", bvar "c"]
conP :: RdrNameStr -> [Pat'] -> Pat'
conP c xs =
#if MIN_VERSION_ghc(9,0,0)
  noExt ConPat
#else
  ConPatIn
#endif
  (valueRdrName c) $ PrefixCon
                $ map (builtPat . parenthesize) xs

-- | A pattern constructor with no arguments.
--
-- > A
-- > =====
-- > conP_ "A"
conP_ :: RdrNameStr -> Pat'
conP_ c = conP c []

recordConP :: RdrNameStr -> [(RdrNameStr, Pat')] -> Pat'
recordConP c fs =
#if MIN_VERSION_ghc(9,0,0)
  noExt ConPat
#else
  ConPatIn
#endif
  (valueRdrName c)
        $ RecCon $ HsRecFields (map mkRecField fs) Nothing -- No ".."
  where
    mkRecField :: (RdrNameStr, Pat') -> LHsRecField' LPat'
    mkRecField (f, p) =
        builtLoc $ HsRecField
            { hsRecFieldLbl =
                builtLoc $ withPlaceHolder $ noExt FieldOcc $ valueRdrName f
            , hsRecFieldArg = builtPat p
            , hsRecPun = False
            }

-- | A bang-pattern.
--
-- > !x
-- > =====
-- > strictP (bvar x)
strictP :: Pat' -> Pat'
strictP = noExt BangPat . builtPat . parenthesize

-- | A lazy pattern match.
--
-- > ~(A x)
-- > =====
-- > lazyP (conP "A" [bvar x])
lazyP :: Pat' -> Pat'
lazyP = noExt LazyPat . builtPat . parenthesize

-- | A pattern type signature
--
-- > x :: y
-- > =====
-- > sigPat (bvar "x") (var "y")
sigP :: Pat' -> HsType' -> Pat'
#if MIN_VERSION_ghc(8,8,0)
sigP p t = noExt SigPat (builtPat p) (patSigType t)
#elif MIN_VERSION_ghc(8,6,0)
sigP p t = SigPat (patSigType t) (builtPat p)
#else
sigP p t = SigPatIn (builtPat p) (patSigType t)
#endif
