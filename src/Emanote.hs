module Emanote
  ( emanate,
    ChangeHandler,
  )
where

import Control.Monad.Logger (MonadLogger)
import Data.LVar (LVar)
import Data.LVar qualified as LVar
import Data.Map.Strict qualified as Map
import Emanote.Prelude (chainM, log)
import Emanote.Source.Loc (Loc)
import Relude
import System.FilePattern (FilePattern)
import System.UnionMount qualified as UM
import UnliftIO (BufferMode (..), MonadUnliftIO, hSetBuffering)
import UnliftIO.IO (hFlush)

type ChangeHandler tag model m = tag -> FilePath -> UM.FileAction (NonEmpty (Loc, FilePath)) -> m (model -> model)

-- | Emanate on-disk sources onto an in-memory `model` (stored in a LVar)
--
-- This is a generic extension to unionMountOnLVar for operating Emanote like
-- apps.
emanate ::
  (MonadUnliftIO m, MonadLogger m, Ord tag) =>
  -- Layers to mount
  Set (Loc, FilePath) ->
  [(tag, FilePattern)] ->
  -- | Ignore patterns
  [FilePattern] ->
  LVar model ->
  model ->
  ChangeHandler tag model m ->
  m ()
emanate layers filePatterns ignorePatterns modelLvar initialModel f = do
  mcmd <-
    UM.unionMountOnLVar
      layers
      filePatterns
      ignorePatterns
      modelLvar
      initialModel
      (mapFsChanges f)
  whenJust mcmd $ \UM.Cmd_Remount -> do
    log "!! Remount suggested !!"
    LVar.set modelLvar initialModel -- Reset the model
    emanate layers filePatterns ignorePatterns modelLvar initialModel f

mapFsChanges :: (MonadIO m, MonadLogger m) => ChangeHandler tag model m -> UM.Change Loc tag -> m (model -> model)
mapFsChanges h ch = do
  withBlockBuffering $
    uncurry (mapFsChangesOnExt h) `chainM` Map.toList ch
  where
    -- Temporarily use block buffering before calling an IO action that is
    -- known ahead to log rapidly, so as to not hamper serial processing speed.
    withBlockBuffering f =
      hSetBuffering stdout (BlockBuffering Nothing)
        *> f
        <* (hSetBuffering stdout LineBuffering >> hFlush stdout)

mapFsChangesOnExt ::
  (MonadIO m, MonadLogger m) =>
  ChangeHandler tag model m ->
  tag ->
  Map FilePath (UM.FileAction (NonEmpty (Loc, FilePath))) ->
  m (model -> model)
mapFsChangesOnExt h fpType fps = do
  uncurry (h fpType) `chainM` Map.toList fps
