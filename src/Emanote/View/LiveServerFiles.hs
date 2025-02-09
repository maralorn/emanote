module Emanote.View.LiveServerFiles
  ( tailwindFullCssUrl,
    isLiveServerFile,
  )
where

import Data.Text qualified as T
import Relude

-- TODO: Check this compile-time using TH?

baseDir :: FilePath
baseDir = "_emanote-live-server"

tailwindFullCssUrl :: Text
tailwindFullCssUrl = toText baseDir <> "/tailwind/2.2.2/tailwind.min.css"

isLiveServerFile :: FilePath -> Bool
isLiveServerFile (toText -> fp) =
  toText baseDir `T.isPrefixOf` fp
