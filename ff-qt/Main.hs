{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

import           Control.Concurrent.STM (TVar, newTVarIO)
import           Control.Monad (void)
import           CRDT.LamportClock (LocalTime, getRealLocalTime)
import           Data.Foldable (for_)
import qualified Data.Text as Text
import           Data.Version (showVersion)
import           Foreign.Hoppy.Runtime (withScopedPtr)
import           Graphics.UI.Qtah.Core.QCoreApplication (exec,
                                                         setApplicationName,
                                                         setApplicationVersion,
                                                         setOrganizationDomain,
                                                         setOrganizationName)
import           Graphics.UI.Qtah.Core.QSettings (setValue, value)
import qualified Graphics.UI.Qtah.Core.QSettings as QSettings
import           Graphics.UI.Qtah.Core.QVariant (toByteArray)
import qualified Graphics.UI.Qtah.Core.QVariant as QVariant
import           Graphics.UI.Qtah.Event (onEvent)
import           Graphics.UI.Qtah.Gui.QCloseEvent (QCloseEvent)
import           Graphics.UI.Qtah.Gui.QShowEvent (QShowEvent)
import           Graphics.UI.Qtah.Widgets.QAbstractItemView (setAlternatingRowColors)
import           Graphics.UI.Qtah.Widgets.QApplication (QApplication)
import qualified Graphics.UI.Qtah.Widgets.QApplication as QApplication
import           Graphics.UI.Qtah.Widgets.QMainWindow (QMainWindow,
                                                       restoreState, saveState,
                                                       setCentralWidget)
import qualified Graphics.UI.Qtah.Widgets.QMainWindow as QMainWindow
import           Graphics.UI.Qtah.Widgets.QTabWidget (QTabWidget, addTab)
import qualified Graphics.UI.Qtah.Widgets.QTabWidget as QTabWidget
import           Graphics.UI.Qtah.Widgets.QTreeView (setHeaderHidden)
import           Graphics.UI.Qtah.Widgets.QTreeWidget (QTreeWidget)
import qualified Graphics.UI.Qtah.Widgets.QTreeWidget as QTreeWidget
import qualified Graphics.UI.Qtah.Widgets.QTreeWidgetItem as QTreeWidgetItem
import           Graphics.UI.Qtah.Widgets.QWidget (QWidgetPtr, restoreGeometry,
                                                   saveGeometry, setFocus,
                                                   setWindowTitle)
import qualified Graphics.UI.Qtah.Widgets.QWidget as QWidget
import           System.Environment (getArgs)

import           FF (loadActiveNotes)
import           FF.Config (Config (Config, dataDir), loadConfig)
import           FF.Storage (runStorage)
import           FF.Types (NoteView (NoteView, text))

import           Paths_ff_qt (version)

main :: IO ()
main = do
    Config { dataDir = Just dataDir } <- loadConfig
    timeVar                           <- newTVarIO =<< getRealLocalTime
    withApp $ \app -> do
        setOrganizationDomain app "ff.cblp.su"
        setOrganizationName   app "ff"
        setApplicationName    app "ff"
        setApplicationVersion app $ showVersion version
        mainWindow <- mkMainWindow dataDir timeVar
        QWidget.show mainWindow
        exec

withApp :: (QApplication -> IO a) -> IO a
withApp = withScopedPtr $ getArgs >>= QApplication.new

mkMainWindow :: FilePath -> TVar LocalTime -> IO QMainWindow
mkMainWindow dataDir timeVar = do
    this <- QMainWindow.new
    setCentralWidget this =<< do
        tabs <- QTabWidget.new
        addTab_ tabs "Agenda" =<< mkAgendaWidget dataDir timeVar
        pure tabs
    setWindowTitle this "ff"

    -- https://wiki.qt.io/Saving_Window_Size_State
    void $ onEvent this $ \(_ :: QShowEvent) -> do
        settings <- QSettings.new
        void
            $   value settings "mainWindowGeometry"
            >>= toByteArray
            >>= restoreGeometry this
        void
            $   value settings "mainWindowState"
            >>= toByteArray
            >>= restoreState this
        pure False
    void $ onEvent this $ \(_ :: QCloseEvent) -> do
        settings <- QSettings.new
        setValue settings "mainWindowGeometry"
            =<< QVariant.newWithByteArray
            =<< saveGeometry this
        setValue settings "mainWindowState"
            =<< QVariant.newWithByteArray
            =<< saveState this
        pure False

    pure this

addTab_ :: QWidgetPtr widget => QTabWidget -> String -> widget -> IO ()
addTab_ tabs name widget = void $ addTab tabs widget name

mkAgendaWidget :: FilePath -> TVar LocalTime -> IO QTreeWidget
mkAgendaWidget dataDir timeVar = do
    this <- QTreeWidget.new
    setAlternatingRowColors this True
    setHeaderHidden         this True
    void $ onEvent this $ \(_ :: QShowEvent) -> do
        setFocus this
        pure False

    notes <- runStorage dataDir timeVar loadActiveNotes
    for_ notes $ \NoteView { text } ->
        QTreeWidgetItem.newWithParentTreeAndStrings this [Text.unpack text]

    pure this