{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module FF.Github
    ( runCmdGithub
    ) where

import           Data.Foldable (toList)
import           Data.Semigroup ((<>))
import           Data.Time (Day, UTCTime (..))
import           GitHub (Error, Id, Issue (..), IssueState (..), Milestone (..),
                         Name, Owner, Repo, URL (..), issueCreatedAt,
                         issueHtmlUrl, issueId, issueMilestone, issueState,
                         issueTitle, untagId)
import           GitHub.Endpoints.Issues (issuesForRepo)

import           FF (splitModes, takeSamples)
import           FF.Storage (DocId (..))
import           FF.Types (Limit, ModeMap, NoteId, NoteView (..), Sample (..),
                           Status (..))

runCmdGithub
    :: Name Owner
    -> Name Repo
    -> Limit
    -> Day  -- ^ today
    -> IO (Either Error (ModeMap Sample))
runCmdGithub owner repo limit today =
    fmap (sampleMaps limit today) <$> issuesForRepo owner repo mempty

sampleMaps :: Foldable t => Limit -> Day -> t Issue -> ModeMap Sample
sampleMaps limit today issues =
    takeSamples (Just limit) . splitModes today . map toNoteView $ toList issues

toNoteView :: Issue -> NoteView
toNoteView Issue{..} = NoteView
    { nid    = toNoteId issueId
    , status = toStatus issueState
    , text   = issueTitle <> maybeUrl
    , start  = utctDay issueCreatedAt
    , end    = maybeMilestone
    }
  where
    maybeUrl = case issueHtmlUrl of
        Just (URL url) -> "\nurl " <> url
        Nothing        -> ""
    maybeMilestone = case issueMilestone of
        Just Milestone{milestoneDueOn = Just UTCTime{utctDay}} -> Just utctDay
        _                                                      -> Nothing

toNoteId :: Id Issue -> NoteId
toNoteId = DocId . show . untagId

toStatus :: IssueState -> Status
toStatus = \case
    StateOpen   -> Active
    StateClosed -> Archived